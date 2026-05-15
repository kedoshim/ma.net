import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ServerProcessService {
  ServerProcessService._internal();

  static final ServerProcessService instance = ServerProcessService._internal();

  Process? _process;

  String _resolveExecutablePath() {
    if (kReleaseMode) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      return p.join(
        exeDir,
        'data',
        'flutter_assets',
        'assets',
        'server',
        'python_server.exe',
      );
    }

    final currentDir = Directory.current.path;
    final projectRoot = Directory(currentDir).parent.path;

    if (Platform.isWindows) {
      return p.join(projectRoot, '.venv', 'Scripts', 'python.exe');
    }

    return p.join(projectRoot, '.venv', 'bin', 'python');
  }

  Future<void> startServer({
    required int port,
    required int slots,
    required bool fixed,
    required String controllerMode,
  }) async {
    if (_process != null) {
      print('Server already running');
      return;
    }

    final executablePath = _resolveExecutablePath();

    if (!File(executablePath).existsSync()) {
      throw Exception('Executable not found at: $executablePath');
    }

    print(
      'Starting server at: $executablePath '
      'port=$port slots=$slots fixed=$fixed mode=$controllerMode',
    );

    final List<String> arguments = [];

    // If debugging, we need to instruct python to run our module
    if (!kReleaseMode) {
      arguments.addAll(['-m', 'src.app.main']);
    }

    // Append the standard flags for the app
    arguments.addAll([
      '--port',
      port.toString(),
      '--slots',
      slots.toString(),
      if (!fixed) '--auto-expand',
      '--controller-type',
      controllerMode,
    ]);

    _process = await Process.start(
      executablePath,
      arguments,
      runInShell: false,
      workingDirectory: kReleaseMode
          ? p.dirname(executablePath)
          : Directory(Directory.current.path).parent.path,
    );

    _process!.stdout
        .transform(SystemEncoding().decoder)
        .listen((data) => print('[SERVER] $data'));

    _process!.stderr
        .transform(SystemEncoding().decoder)
        .listen((data) => print('[SERVER ERROR] $data'));

    _process!.exitCode.then((code) {
      print('[SERVER] Process exited with code $code');
      _process = null; // Clear process so it can be restarted later
    });
  }

  Future<void> stopServer() async {
    if (_process == null) return;

    try {
      await Process.run('taskkill', [
        '/PID',
        _process!.pid.toString(),
        '/T',
        '/F',
      ]);

      print('Python server killed: ${_process!.pid}');
    } catch (e) {
      print('Failed to kill server: $e');
    }

    _process = null;
  }
}
