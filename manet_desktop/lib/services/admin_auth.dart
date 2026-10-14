import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

/// The admin token this app hands the server it spawns. Every call that
/// controls the host (REST and the `/ws/admin` feed) must carry it; phones
/// never get it.
class AdminAuth {
  AdminAuth._();

  static const String header = 'X-Manet-Admin';
  static const String queryParameter = 'admin';

  // A server started by hand (dev tools) takes its token from the same
  // variable; spawned servers get a fresh one from [rotate].
  static String _token = Platform.environment['MANET_ADMIN_TOKEN'] ?? '';

  static String get token => _token;

  /// A fresh token for the next server process.
  static String rotate() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    _token = base64Url.encode(bytes).replaceAll('=', '');
    return _token;
  }

  static Map<String, String> get headers =>
      _token.isEmpty ? const {} : {header: _token};

  /// For clients that cannot set headers (the admin socket).
  static Uri withToken(Uri uri) => _token.isEmpty
      ? uri
      : uri.replace(
          queryParameters: {...uri.queryParameters, queryParameter: _token},
        );

  /// An HTTP client that adds the token to every request.
  static final http.Client client = _AdminClient();
}

class _AdminClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(AdminAuth.headers);
    return _inner.send(request);
  }
}
