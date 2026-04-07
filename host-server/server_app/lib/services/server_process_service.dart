import 'dart:io';
import 'package:path/path.dart' as p;

class ServerProcessService {
  ServerProcessService._internal();

  static final ServerProcessService instance =
      ServerProcessService._internal();

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
    if (_process != null) {
      print('Server already running');
      return;
    }

    final pythonPath = _resolvePythonPath();

    if (!File(pythonPath).existsSync()) {
      throw Exception('Python not found at: $pythonPath');
    }

    print(
      'Starting server with Python at: $pythonPath '
      'port=$port slots=$slots fixed=$fixed mode=$controllerMode',
    );

    _process = await Process.start(
      pythonPath,
      [
        '-m',
        'src.app.main',
        '--port',
        port.toString(),
        '--slots',
        slots.toString(),
        if (!fixed) '--auto-expand',
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