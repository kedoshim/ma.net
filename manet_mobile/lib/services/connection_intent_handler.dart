import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

class ConnectionIntentHandler {
  /// Parses a deep link [Uri] and extracts the host and port string.
  ///
  /// Handles two formats:
  /// 1. HTTP/HTTPS: http://192.168.100.80:8765
  /// 2. Custom Scheme: manet://connect?host=192.168.100.80:8765
  static String? parseDeepLinkToHost(Uri uri) {
    if (uri.scheme == 'manet' && uri.host == 'connect') {
      // Extract from query parameter
      return uri.queryParameters['host'];
    } else if (uri.scheme == 'http' || uri.scheme == 'https') {
      // Extract directly from authority (host:port)
      if (uri.hasPort) {
        return '${uri.host}:${uri.port}';
      }
      return uri.host;
    }
    return null;
  }

  /// Executes the connection flow when a valid host is found via deep link.
  static Future<void> handleConnection(
    BuildContext context,
    String hostAddress,
  ) async {
    // Save to shared preferences so the app uses it as the default
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_host', hostAddress);

    // Show brief feedback to the user
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.status.connectViaLink(hostAddress)),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // TODO: Automatically trigger your controller screen navigation here.
      // Example:
      // Navigator.of(context).pushNamedAndRemoveUntil(
      //   '/controller',
      //   (route) => false,
      // );
    }
  }
}
