import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../utils/demo_config.dart';

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

  static const int _maxLogLines = 2000;

  Process? _process;
  int? _port;
  // Bumped on every start/stop so callbacks from an old process never touch
  // the state of a newer one.
  int _generation = 0;
  final List<String> _logs = [];

  List<String> get logs => List.unmodifiable(_logs);

  void _log(String message) {
    final time = DateTime.now().toIso8601String().split('T').last;
    final formatted = '[$time] $message';
    _logs.add(formatted);
    if (_logs.length > _maxLogLines) {
      _logs.removeRange(0, _logs.length - _maxLogLines);
    }
    debugPrint(formatted);
  }

  String _resolveExecutablePath() {
    if (kReleaseMode) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      // One-dir PyInstaller build installed next to MaNet.exe: starts fast
      // because nothing has to be unpacked to %TEMP% on every launch.
      final oneDir = p.join(exeDir, 'server', 'manet_network_service.exe');
      if (File(oneDir).existsSync()) {
        return oneDir;
      }
      // Legacy one-file build bundled as a Flutter asset.
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
      // A listening local port accepts in ~1ms. A closed one makes Windows
      // retry for ~1s before refusing, so cap the wait instead of paying it
      // on every poll.
      final socket = await Socket.connect(
        '127.0.0.1',
        port,
        timeout: const Duration(milliseconds: 150),
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
      if (!fixed && !isDemoMode) '--auto-expand',
      '--controller-type',
      controllerMode,
      if (isDemoMode) '--demo',
      // The server exits by itself (releasing its gamepads) when this app
      // process ends, however it ends.
      '--parent-pid',
      pid.toString(),
    ]);

    _log('Spawning process with arguments: $arguments');
    bool crashed = false;
    final generation = ++_generation;

    try {
      final process = await Process.start(
        executablePath,
        arguments,
        runInShell: false,
        workingDirectory: _resolveWorkingDirectory(),
      );
      _process = process;
      _port = port;
      _recordServer(process.pid, port);

      process.exitCode.then((code) {
        if (generation != _generation) return;
        crashed = true;
        _log('Process exited unexpectedly with code $code');
        _process = null;
      });

      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen((line) {
            if (line.trim().isNotEmpty) _log('[STDOUT] ${line.trim()}');
          });

      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen((line) {
            if (line.trim().isNotEmpty) _log('[STDERR] ${line.trim()}');
          });
    } catch (e) {
      _log('Failed to spawn process: $e');
      return ServerStartupResult(
        ServerStartupStatus.unknown,
        'Falha crítica ao iniciar o processo: $e',
      );
    }

    _log('Waiting for server to bind to port $port...');
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      if (generation != _generation) {
        return ServerStartupResult(
          ServerStartupStatus.unknown,
          'A inicialização foi cancelada.',
        );
      }
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
      await Future.delayed(const Duration(milliseconds: 150));
    }

    _log('Startup timeout after 15 seconds.');
    await stopServer();
    return ServerStartupResult(
      ServerStartupStatus.timeout,
      'O servidor demorou muito para responder e a operação foi cancelada.',
    );
  }

  Future<void> stopServer() async {
    final process = _process;
    final port = _port;
    if (process == null) return;
    _generation++;
    _process = null;

    // The server unplugs its gamepads and exits on its own; killing it is
    // only the fallback when it doesn't answer in time.
    if (port != null) await _requestGracefulShutdown(port);
    final exited = await process.exitCode
        .then((_) => true)
        .timeout(_exitGracePeriod, onTimeout: () => false);
    if (!exited) await _killTree(process.pid);
    _forgetServer();
    _log(exited ? 'Server exited: ${process.pid}' : 'Server killed: ${process.pid}');
  }

  /// A hot restart (Shift+R in `flutter run`) wipes Dart state but keeps
  /// this process, so the server started before it would be orphaned.
  /// Call once at startup: stops the server recorded for this process.
  Future<void> stopServerFromPreviousRun() async {
    final file = _runFile();
    if (!file.existsSync()) return;
    try {
      final data = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      final serverPid = data['serverPid'] as int;
      final port = data['port'] as int;
      _log('Stopping server $serverPid left over from before a restart');
      if (await _requestGracefulShutdown(port)) {
        // It replied and exits right after (~150ms); let the port free up.
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        await _killTree(serverPid);
      }
    } catch (e) {
      _log('Could not stop leftover server: $e');
    } finally {
      _forgetServer();
    }
  }

  static const Duration _exitGracePeriod = Duration(milliseconds: 1500);

  File _runFile() {
    final base =
        Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    return File(p.join(base, 'MaNet', 'run', 'server-$pid.json'));
  }

  void _recordServer(int serverPid, int port) {
    try {
      final file = _runFile();
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(json.encode({'serverPid': serverPid, 'port': port}));
    } catch (e) {
      _log('Could not record server pid: $e');
    }
  }

  void _forgetServer() {
    try {
      final file = _runFile();
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  Future<void> _killTree(int processId) async {
    try {
      if (Platform.isWindows) {
        // /T also takes the real interpreter that the dev venv launcher spawns.
        await Process.run('taskkill', [
          '/PID',
          processId.toString(),
          '/T',
          '/F',
        ]).timeout(const Duration(seconds: 3));
      } else {
        Process.killPid(processId, ProcessSignal.sigkill);
      }
    } catch (e) {
      _log('Failed to kill server $processId: $e');
    }
  }

  /// Ask the server to unplug its virtual gamepads and exit. Best effort
  /// and bounded; returns whether the server acknowledged.
  Future<bool> _requestGracefulShutdown(int port) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 500);
    try {
      final request = await client
          .postUrl(Uri.parse('http://127.0.0.1:$port/api/server/shutdown'))
          .timeout(const Duration(milliseconds: 500));
      final response = await request.close().timeout(
        const Duration(milliseconds: 1000),
      );
      await response.drain<void>();
      return response.statusCode == 200;
    } catch (e) {
      _log('Graceful shutdown request failed: $e');
      return false;
    } finally {
      client.close(force: true);
    }
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
