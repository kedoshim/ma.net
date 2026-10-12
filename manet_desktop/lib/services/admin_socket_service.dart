import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// One shared `/ws/admin` connection per server, with automatic reconnect.
///
/// The lobby, the window service and the startup pipeline all listen to the
/// same broadcast stream. The socket opens with the first listener, closes
/// with the last one, and reconnects with backoff if the server restarts.
/// The server sends a full `slot_update` on every (re)connect, so listeners
/// resynchronize without extra calls.
class AdminSocketService {
  static final Map<String, AdminSocketService> _instances = {};

  factory AdminSocketService.forBaseUrl(String baseUrl) =>
      _instances.putIfAbsent(baseUrl, () => AdminSocketService._(baseUrl));

  AdminSocketService._(this._baseUrl) {
    _controller = StreamController<Map<String, dynamic>>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
  }

  final String _baseUrl;
  late final StreamController<Map<String, dynamic>> _controller;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _active = false;

  Stream<Map<String, dynamic>> get events => _controller.stream;

  Uri get _wsUri {
    final httpUri = Uri.parse(_baseUrl);
    return httpUri.replace(
      scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/admin',
    );
  }

  void _start() {
    _active = true;
    _open();
  }

  void _open() {
    if (!_active) return;
    _retryTimer?.cancel();

    final channel = WebSocketChannel.connect(_wsUri);
    _channel = channel;
    _subscription = channel.stream.listen(
      (message) {
        _attempt = 0;
        try {
          final data = json.decode(message as String);
          if (data is Map<String, dynamic>) _controller.add(data);
        } catch (e) {
          debugPrint('[ADMIN SOCKET] Ignoring malformed message: $e');
        }
      },
      onError: (Object e) {
        debugPrint('[ADMIN SOCKET] Error: $e');
        _scheduleReconnect(channel);
      },
      onDone: () => _scheduleReconnect(channel),
      cancelOnError: true,
    );
  }

  void _scheduleReconnect(WebSocketChannel channel) {
    if (!_active || !identical(channel, _channel)) return;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    final delayMs = min(5000, 250 * (1 << min(_attempt, 5)));
    _attempt++;
    debugPrint('[ADMIN SOCKET] Disconnected; retrying in ${delayMs}ms');
    _retryTimer = Timer(Duration(milliseconds: delayMs), _open);
  }

  void _stop() {
    _active = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _attempt = 0;
  }
}
