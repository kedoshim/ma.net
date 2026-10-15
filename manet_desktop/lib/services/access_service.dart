import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/player_face.dart';
import '../utils/app_preferences.dart';
import 'admin_auth.dart';
import 'host_api_service.dart';

/// Join rule for a kind of connection (see the server's access_control).
enum AccessMode { open, password, approval }

AccessMode _parseMode(Object? value, AccessMode fallback) =>
    AccessMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => fallback,
    );

@immutable
class JoinRequest {
  final String deviceId;
  final String name;
  final bool online;
  /// The face the player made on their phone before asking.
  final PlayerFaceData face;

  const JoinRequest({
    required this.deviceId,
    required this.name,
    required this.online,
    required this.face,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) => JoinRequest(
    deviceId: json['deviceId'] as String,
    name: json['name'] as String? ?? '',
    online: json['origin'] == 'online',
    face: PlayerFaceData.fromJson(json),
  );
}

@immutable
class AccessStatus {
  final AccessMode lanMode;
  final AccessMode onlineMode;
  final List<JoinRequest> pending;
  final int bannedCount;

  const AccessStatus({
    this.lanMode = AccessMode.open,
    this.onlineMode = AccessMode.approval,
    this.pending = const [],
    this.bannedCount = 0,
  });

  factory AccessStatus.fromJson(Map<String, dynamic> json) => AccessStatus(
    lanMode: _parseMode(json['lanMode'], AccessMode.open),
    onlineMode: _parseMode(json['onlineMode'], AccessMode.approval),
    pending: [
      for (final item in json['pending'] as List? ?? const [])
        JoinRequest.fromJson(item as Map<String, dynamic>),
    ],
    bannedCount: json['bannedCount'] as int? ?? 0,
  );
}

/// Who may join this server, and the phones waiting for the host's answer.
class AccessService extends ValueNotifier<AccessStatus> {
  static final Map<String, AccessService> _instances = {};

  factory AccessService.of(HostApiService api) =>
      _instances.putIfAbsent(api.baseUrl, () => AccessService._(api));

  AccessService._(this._api) : super(const AccessStatus()) {
    _subscription = _api.connectAdminSocket().listen((event) {
      if (event['type'] == 'access_update') {
        value = AccessStatus.fromJson(event);
        unawaited(_resyncIfReset(event['passwordSet'] == true));
      }
    });
    // The server starts with defaults every run.
    unawaited(pushSaved());
  }

  final HostApiService _api;
  StreamSubscription? _subscription;

  static const Duration _timeout = Duration(seconds: 5);

  Future<void> pushSaved() async {
    await _post('/api/access/settings', {
      'lanMode': (await AppPreferences.accessModeLan()).name,
      'onlineMode': (await AppPreferences.accessModeOnline()).name,
      'password': await AppPreferences.roomPassword(),
    });
  }

  /// A restarted server comes back with defaults: put the saved rules back.
  Future<void> _resyncIfReset(bool passwordSet) async {
    final lan = await AppPreferences.accessModeLan();
    final online = await AppPreferences.accessModeOnline();
    final hasPassword = (await AppPreferences.roomPassword()).isNotEmpty;
    if (value.lanMode != lan || value.onlineMode != online || passwordSet != hasPassword) {
      await pushSaved();
    }
  }

  /// Saves and applies the rules; null fields are left as they are.
  Future<void> configure({
    AccessMode? lanMode,
    AccessMode? onlineMode,
    String? password,
  }) async {
    if (lanMode != null) await AppPreferences.setAccessModeLan(lanMode);
    if (onlineMode != null) await AppPreferences.setAccessModeOnline(onlineMode);
    if (password != null) await AppPreferences.setRoomPassword(password);
    await _post('/api/access/settings', {
      if (lanMode != null) 'lanMode': lanMode.name,
      if (onlineMode != null) 'onlineMode': onlineMode.name,
      if (password != null) 'password': password,
    });
  }

  Future<void> answer(String deviceId, {required bool accept, bool ban = false}) =>
      _post('/api/access/answer', {'deviceId': deviceId, 'accept': accept, 'ban': ban});

  Future<void> kick(String deviceId, {bool ban = false}) =>
      _post('/api/access/kick', {'deviceId': deviceId, 'ban': ban});

  Future<void> unbanAll() => _post('/api/access/unban', const {});

  Future<void> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await AdminAuth.client
          .post(
            Uri.parse('${_api.baseUrl}$path'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(_timeout);
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data is Map<String, dynamic> && data.containsKey('lanMode')) {
        value = AccessStatus.fromJson(data);
      }
    } catch (e) {
      debugPrint('[ACCESS] POST $path failed: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _instances.remove(_api.baseUrl);
    super.dispose();
  }
}
