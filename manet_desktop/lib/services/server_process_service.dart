import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

enum ServerStartupStatus {
  success,
  portInUse,
  missingExecutable,
  missingDriver,
  crashed,
  timeout,
  unknown,
}

class ServerStartupResult {
  final ServerStartupStatus status;
  final String message;

  ServerStartupResult(this.status, this.message);

  bool get isSuccess => status == ServerStartupStatus.success;
}

class ServerProcessService {
  ServerProcessService._internal();

  static final ServerProcessService instance = ServerProcessService._internal();

  Process? _process;
  final List<String> _logs = [];

  List<String> get logs => List.unmodifiable(_logs);

  void _log(String message) {
    final time = DateTime.now().toIso8601String().split('T').last;
    final formatted = '[$time] $message';
    _logs.add(formatted);
    debugPrint(formatted);
  }

  String _resolveExecutablePath() {
    if (kReleaseMode) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      return p.join(
        exeDir,
        'data',
        'flutter_assets',
        'assets',
        'server',
        'manet_network_service.exe',
      );
    }

    final currentDir = Directory.current.path;
    final projectRoot = Directory(currentDir).parent.path;

    if (Platform.isWindows) {
      return p.join(
        projectRoot,
        'manet_server',
        '.venv',
        'Scripts',
        'python.exe',
      );
    }

    return p.join(projectRoot, 'manet_server', '.venv', 'bin', 'python');
  }

  String _resolveWorkingDirectory() {
    if (kReleaseMode) {
      return p.dirname(_resolveExecutablePath());
    }

    final currentDir = Directory.current.path;
    final projectRoot = Directory(currentDir).parent.path;

    return p.join(projectRoot, 'manet_server');
  }

  Future<bool> _isDriverInstalled() async {
    if (!Platform.isWindows) return true;
    try {
      final result = await Process.run('sc', ['query', 'ViGEmBus']);
      if (result.stdout.toString().contains('1060')) {
        return false;
      }
      return true;
    } catch (e) {
      _log('[DRIVER CHECK] sc query failed: $e');
      final driverFile = File(r'C:\Windows\System32\drivers\ViGEmBus.sys');
      final exists = driverFile.existsSync();
      _log('[DRIVER CHECK] Fallback check: ViGEmBus.sys exists = $exists');
      return exists;
    }
  }

  Future<bool> _isPortInUse(int port) async {
    try {
      final socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await socket.close();
      return false;
    } catch (e) {
      return true;
    }
  }

  Future<void> _killOrphanedServers() async {
    if (!Platform.isWindows) return;
    try {
      _log('Cleaning up orphaned manet_network_service.exe processes...');
      await Process.run('taskkill', [
        '/IM',
        'manet_network_service.exe',
        '/T',
        '/F',
      ]);
    } catch (e) {
      _log('Cleanup of orphaned processes failed: $e');
    }
  }

  Future<bool> isServerResponding(int port) async {
    try {
      final socket = await Socket.connect(
        '127.0.0.1',
        port,
        timeout: const Duration(milliseconds: 500),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<ServerStartupResult> startServer({
    required int port,
    required int slots,
    required bool fixed,
    required String controllerMode,
  }) async {
    _logs.clear();
    _log('Initializing server startup sequence...');

    if (_process != null) {
      _log('Server is already running. Stopping it first...');
      await stopServer();
    }

    _log('Checking controller driver...');
    if (!await _isDriverInstalled()) {
      return ServerStartupResult(
        ServerStartupStatus.missingDriver,
        'O driver de controle ViGEmBus não foi encontrado no sistema.',
      );
    }

    final executablePath = _resolveExecutablePath();
    _log('Target executable: $executablePath');

    if (!File(executablePath).existsSync()) {
      return ServerStartupResult(
        ServerStartupStatus.missingExecutable,
        'Não foi possível encontrar o executável do servidor.',
      );
    }

    _log('Verifying port $port availability...');
    if (await _isPortInUse(port)) {
      await _killOrphanedServers();
      if (await _isPortInUse(port)) {
        return ServerStartupResult(
          ServerStartupStatus.portInUse,
          'A porta $port já está em uso por outro programa.',
        );
      }
    }

    final List<String> arguments = [];

    if (!kReleaseMode) {
      arguments.addAll(['-m', 'src.app.main']);
    }

    arguments.addAll([
      '--port',
      port.toString(),
      '--slots',
      slots.toString(),
      if (!fixed) '--auto-expand',
      '--controller-type',
      controllerMode,
    ]);

    _log('Spawning process with arguments: $arguments');
    bool crashed = false;

    try {
      _process = await Process.start(
        executablePath,
        arguments,
        runInShell: false,
        workingDirectory: _resolveWorkingDirectory(),
      );

      _process!.exitCode.then((code) {
        crashed = true;
        _log('Process exited unexpectedly with code $code');
        _process = null;
      });

      _process!.stdout.transform(utf8.decoder).listen((data) {
        for (var line in data.split('\n')) {
          if (line.trim().isNotEmpty) _log('[STDOUT] ${line.trim()}');
        }
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        for (var line in data.split('\n')) {
          if (line.trim().isNotEmpty) _log('[STDERR] ${line.trim()}');
        }
      });
    } catch (e) {
      _log('Failed to spawn process: $e');
      return ServerStartupResult(
        ServerStartupStatus.unknown,
        'Falha crítica ao iniciar o processo: $e',
      );
    }

    _log('Waiting for server to bind to port $port...');
    for (int i = 0; i < 20; i++) {
      if (crashed) {
        return ServerStartupResult(
          ServerStartupStatus.crashed,
          'O servidor fechou inesperadamente durante a inicialização.',
        );
      }
      if (await isServerResponding(port)) {
        _log('Server successfully bound to port $port and is responding.');
        return ServerStartupResult(
          ServerStartupStatus.success,
          'Servidor iniciado com sucesso.',
        );
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _log('Startup timeout after 10 seconds.');
    await stopServer();
    return ServerStartupResult(
      ServerStartupStatus.timeout,
      'O servidor demorou muito para responder e a operação foi cancelada.',
    );
  }

  Future<void> stopServer() async {
    if (_process == null) return;

    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', [
          '/PID',
          _process!.pid.toString(),
          '/T',
          '/F',
        ]);
      } else {
        _process!.kill(ProcessSignal.sigkill);
      }
      _log('Server killed: ${_process!.pid}');
    } catch (e) {
      _log('Failed to kill server: $e');
    }

    _process = null;
  }

  Future<bool> installDriver() async {
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final candidates = <String>[
        p.join(
          exeDir,
          'data',
          'flutter_assets',
          'assets',
          'drivers',
          'ViGEmBus_Setup.exe',
        ),
        p.join(
          exeDir,
          'data',
          'flutter_assets',
          'drivers',
          'ViGEmBus_Setup.exe',
        ),
        p.join(
          Directory.current.path,
          'assets',
          'drivers',
          'ViGEmBus_Setup.exe',
        ),
        p.join(Directory.current.path, 'drivers', 'ViGEmBus_Setup.exe'),
        p.join(
          p.dirname(Platform.script.toFilePath()),
          'assets',
          'drivers',
          'ViGEmBus_Setup.exe',
        ),
      ];

      String? installerPath;
      for (final path in candidates) {
        if (File(path).existsSync()) {
          installerPath = path;
          break;
        }
      }

      if (installerPath != null) {
        _log('Launching driver installer: $installerPath');
        await Process.start(installerPath, [], mode: ProcessStartMode.detached);
        return true;
      } else {
        _log('Driver installer not found in any expected location.');
        return false;
      }
    } catch (e) {
      _log('Failed to launch driver installer: $e');
      return false;
    }
  }
}
