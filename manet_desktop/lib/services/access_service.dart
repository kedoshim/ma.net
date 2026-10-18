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
  /// False in "online only": new phones on the local network are refused.
  final bool lanEnabled;
  final bool passwordSet;
  final bool onlinePasswordSet;
  final List<JoinRequest> pending;
  final int bannedCount;

  const AccessStatus({
    this.lanMode = AccessMode.open,
    this.onlineMode = AccessMode.approval,
    this.lanEnabled = true,
    this.passwordSet = false,
    this.onlinePasswordSet = false,
    this.pending = const [],
    this.bannedCount = 0,
  });

  factory AccessStatus.fromJson(Map<String, dynamic> json) => AccessStatus(
    lanMode: _parseMode(json['lanMode'], AccessMode.open),
    onlineMode: _parseMode(json['onlineMode'], AccessMode.approval),
    lanEnabled: json['lanEnabled'] as bool? ?? true,
    passwordSet: json['passwordSet'] == true,
    onlinePasswordSet: (json['onlinePasswordSet'] ?? json['passwordSet']) == true,
    pending: [
      for (final item in json['pending'] as List? ?? const [])
        JoinRequest.fromJson(item as Map<String, dynamic>),
    ],
    bannedCount: json['bannedCount'] as int? ?? 0,
  );
}

/// The rules as the host set them: one global rule, optionally a separate
/// one for internet joins.
@immutable
class AccessRules {
  final AccessMode mode;
  final String password;
  final bool onlineOverride;
  final AccessMode onlineMode;
  final String onlinePassword;

  const AccessRules({
    required this.mode,
    required this.password,
    required this.onlineOverride,
    required this.onlineMode,
    required this.onlinePassword,
  });

  static Future<AccessRules> load() async => AccessRules(
    mode: await AppPreferences.accessModeLan(),
    password: await AppPreferences.roomPassword(),
    onlineOverride: await AppPreferences.onlineRuleOverride(),
    onlineMode: await AppPreferences.accessModeOnline(),
    onlinePassword: await AppPreferences.roomPasswordOnline(),
  );

  AccessMode get effectiveOnlineMode => onlineOverride ? onlineMode : mode;
  String get effectiveOnlinePassword => onlineOverride ? onlinePassword : password;
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
        unawaited(_resyncIfReset());
      }
    });
    // The server starts with defaults every run.
    unawaited(pushSaved());
  }

  final HostApiService _api;
  StreamSubscription? _subscription;
  bool _lanEnabled = true;
  DateTime _lastResync = DateTime.fromMillisecondsSinceEpoch(0);

  static const Duration _timeout = Duration(seconds: 5);

  Future<void> pushSaved() async {
    final rules = await AccessRules.load();
    await _post('/api/access/settings', {
      'lanMode': rules.mode.name,
      'onlineMode': rules.effectiveOnlineMode.name,
      'password': rules.password,
      'onlinePassword': rules.effectiveOnlinePassword,
      'lanEnabled': _lanEnabled,
    });
  }

  /// A restarted server comes back with defaults: put the saved rules back.
  Future<void> _resyncIfReset() async {
    // An older server that misses a field would otherwise loop forever.
    final now = DateTime.now();
    if (now.difference(_lastResync) < const Duration(seconds: 5)) return;
    final rules = await AccessRules.load();
    final status = value;
    if (status.lanMode != rules.mode ||
        status.onlineMode != rules.effectiveOnlineMode ||
        status.lanEnabled != _lanEnabled ||
        status.passwordSet != rules.password.isNotEmpty ||
        status.onlinePasswordSet != rules.effectiveOnlinePassword.isNotEmpty) {
      _lastResync = now;
      await pushSaved();
    }
  }

  /// Saves and applies the rules; null fields are left as they are.
  Future<void> configure({
    AccessMode? mode,
    String? password,
    bool? onlineOverride,
    AccessMode? onlineMode,
    String? onlinePassword,
  }) async {
    if (mode != null) await AppPreferences.setAccessModeLan(mode);
    if (password != null) await AppPreferences.setRoomPassword(password);
    if (onlineOverride != null) await AppPreferences.setOnlineRuleOverride(onlineOverride);
    if (onlineMode != null) await AppPreferences.setAccessModeOnline(onlineMode);
    if (onlinePassword != null) await AppPreferences.setRoomPasswordOnline(onlinePassword);
    await pushSaved();
  }

  /// "Online only" refuses new phones from the local network.
  Future<void> setLanEnabled(bool enabled) async {
    _lanEnabled = enabled;
    await pushSaved();
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
