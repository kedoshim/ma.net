import 'dart:io';
import 'package:path/path.dart' as p;

class ServerProcessService {
  ServerProcessService._internal();

  static final ServerProcessService instance =
      ServerProcessService._internal();

  factory ServerProcessService() => instance;

  Process? _process;

  String _resolvePythonPath() {
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
    final pythonPath = _resolvePythonPath();

    if (!File(pythonPath).existsSync()) {
      throw Exception('Python not found at: $pythonPath');
    }

    print('Starting server with Python at: $pythonPath with port: $port, slots: $slots, fixed: $fixed, controllerMode: $controllerMode');

    _process = await Process.start(
      pythonPath,
      [
        '-m',
        'src.app.main',
        '--port',
        port.toString(),
        '--slots',
        slots.toString(),
        if (!fixed)'--auto-expand',
        '--controller-type',
        controllerMode,
      ],
      runInShell: false,
      workingDirectory: Directory(Directory.current.path).parent.path,
    );

    _process!.stdout
        .transform(SystemEncoding().decoder)
        .listen((data) => print('[SERVER] $data'));

    _process!.stderr
        .transform(SystemEncoding().decoder)
        .listen((data) => print('[SERVER ERROR] $data'));
  }

  Future<void> stopServer() async {
    if (_process != null) {
      await Process.run('taskkill', [
        '/PID',
        _process!.pid.toString(),
        '/T',
        '/F',
      ]);

      _process = null;
    }
  }
}