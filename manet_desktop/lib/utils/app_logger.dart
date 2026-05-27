import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class AppLogger {
  static File? _logFile;

  static Future<void> init() async {
    try {
      final appData = Platform.environment['APPDATA'];
      if (appData != null) {
        final logDir = Directory(p.join(appData, 'MaNet', 'logs'));
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        _logFile = File(p.join(logDir.path, 'latest.log'));
      }
    } catch (e) {
      debugPrint('Failed to initialize logger: $e');
    }

    // Global error handler for Flutter layout/framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      error(
        'Uncaught Flutter Error: ${details.exception}',
        details.exception,
        details.stack,
      );
    };

    // Global error handler for unhandled Async Dart errors
    PlatformDispatcher.instance.onError = (errorObj, stack) {
      error('Uncaught Async Dart Error: $errorObj', errorObj, stack);
      return true;
    };

    info('Flutter desktop application started.');
  }

  static void info(String message) {
    _write('INFO', message);
  }

  static void warning(String message) {
    _write('WARNING', message);
  }

  static void error(String message, [dynamic error, StackTrace? stack]) {
    _write(
      'ERROR',
      '$message${error != null ? '\nDetails: $error' : ''}${stack != null ? '\nStack:\n$stack' : ''}',
    );
  }

  static void _write(String level, String message) {
    final now = DateTime.now().toIso8601String();
    final log = '$now | ${level.padRight(8)} | FLUTTER | $message\n';

    debugPrint(log);

    if (_logFile != null) {
      try {
        _logFile!.writeAsStringSync(log, mode: FileMode.append);
      } catch (_) {}
    }
  }
}
