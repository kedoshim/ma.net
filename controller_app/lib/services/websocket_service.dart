import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  late final WebSocketChannel channel;

  WebSocketService._(this.channel);

  static Future<WebSocketService> connectUri(Uri uri) async {
    final channel = WebSocketChannel.connect(uri);
    return WebSocketService._(channel);
  }

  void send(Map<String, dynamic> data) {
    channel.sink.add(jsonEncode(data));
  }

  void dispose() {
    channel.sink.close();
  }
}
