import 'preferences_service.dart';
import 'websocket_service.dart';

class ControllerConnectionManager {
  ControllerConnectionManager._();

  static final ControllerConnectionManager instance =
      ControllerConnectionManager._();

  WebSocketService? ws;

  void disconnect() {
    ws?.channel.sink.close();
    ws = null;
  }

  Future<WebSocketService> getConnection() async {
    ws ??= await _createConnection();
    return ws!;
  }

  Future<WebSocketService> _createConnection() async {
    final prefs = PreferencesService.instance;

    final deviceId = await prefs.getDeviceId();
    final playerFace = await prefs.getOrCreatePlayerFace();
    final isHttps =
        await prefs.getServerHttps() ?? (Uri.base.scheme == 'https');

    final wsUri = Uri(
      scheme: isHttps ? 'wss' : 'ws',
      host: await prefs.getServerHost() ?? Uri.base.host,
      port: await prefs.getServerPort() ?? Uri.base.port,
      path: '/ws',
      queryParameters: {
        'deviceId': deviceId,
        ...playerFace.toJson().map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        ),
      },
    );

    return WebSocketService.connectUri(wsUri);
  }
}
