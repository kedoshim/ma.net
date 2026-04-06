import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class WebSocketService {
  late final WebSocketChannel channel;

  WebSocketService._(this.channel);

  static Future<WebSocketService> connect(String host) async {
    final prefs = await SharedPreferences.getInstance();

    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }

    final uri = Uri.parse(
      'ws://$host:8000/ws?deviceId=$deviceId',
    );

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