import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'admin_auth.dart';
import 'host_api_service.dart';

enum OnlineState { off, starting, verifying, online, error }

/// State of "Play online" (the server's Cloudflare tunnel).
@immutable
class OnlineStatus {
  final OnlineState state;
  final String? url;
  final String? error;

  const OnlineStatus({this.state = OnlineState.off, this.url, this.error});

  factory OnlineStatus.fromJson(Map<String, dynamic> json) {
    final state = OnlineState.values.firstWhere(
      (value) => value.name == json['state'],
      orElse: () => OnlineState.off,
    );
    return OnlineStatus(
      state: state,
      url: json['url'] as String?,
      error: json['error'] as String?,
    );
  }

  bool get isOnline => state == OnlineState.online && url != null;
  bool get isBusy =>
      state == OnlineState.starting || state == OnlineState.verifying;

  /// The tunnel as a connection, so QR widgets can show it like any other.
  ConnectionInfo? get connection {
    if (!isOnline) return null;
    final uri = Uri.parse(url!);
    return ConnectionInfo(
      id: OnlineService.connectionId,
      url: url!,
      wsUrl: uri.replace(scheme: 'wss', path: '/ws').toString(),
      ip: uri.host,
      displayNameKey: 'connection_label_internet',
      kind: 'internet',
      recommended: false,
      selected: true,
      preferred: false,
      lastSuccessful: false,
    );
  }
}

/// Follows and drives "Play online" for one server.
class OnlineService extends ValueNotifier<OnlineStatus> {
  /// Connection id the server's QR endpoint maps to the tunnel address.
  static const String connectionId = 'internet';

  static final Map<String, OnlineService> _instances = {};

  factory OnlineService.of(HostApiService api) =>
      _instances.putIfAbsent(api.baseUrl, () => OnlineService._(api));

  OnlineService._(this._api) : super(const OnlineStatus()) {
    _subscription = _api.connectAdminSocket().listen((event) {
      if (event['type'] == 'online_status') {
        value = OnlineStatus.fromJson(event);
      }
    });
    unawaited(refresh());
  }

  final HostApiService _api;
  StreamSubscription? _subscription;

  static const Duration _timeout = Duration(seconds: 10);

  String get qrUrl => _api.getQrCodeUrl(connectionId);

  Future<void> refresh() => _call('GET', '/api/online');

  Future<void> start() => _call('POST', '/api/online/start');

  Future<void> stop() => _call('POST', '/api/online/stop');

  Future<void> _call(String method, String path) async {
    try {
      final uri = Uri.parse('${_api.baseUrl}$path');
      final response = await (method == 'GET'
              ? AdminAuth.client.get(uri)
              : AdminAuth.client.post(uri))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        value = OnlineStatus.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('[ONLINE] $method $path failed: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _instances.remove(_api.baseUrl);
    super.dispose();
  }
}
