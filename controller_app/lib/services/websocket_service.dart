import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  final WebSocketChannel channel;

  WebSocketService(String host)
      : channel = WebSocketChannel.connect(
          Uri.parse('ws://$host:8000/ws'),
        );

  void send(Map<String, dynamic> data) {
    channel.sink.add(jsonEncode(data));
  }

  void dispose() {
    channel.sink.close();
  }
}