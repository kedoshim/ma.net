import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/app_preferences.dart';
import 'access_service.dart';
import 'admin_auth.dart';
import 'host_api_service.dart';
import 'online_service.dart';

/// Where phones may join from: the local network, the internet (the
/// tunnel), or both at once.
enum NetworkMode { local, both, online }

/// Which address the lobby and overlay QR codes point at.
enum QrTarget { local, online }

/// The PC's Windows Mobile Hotspot, when it is on.
@immutable
class HotspotStatus {
  final bool active;
  final String? ssid;
  final bool hasPassword;

  const HotspotStatus({
    this.active = false,
    this.ssid,
    this.hasPassword = false,
  });

  factory HotspotStatus.fromJson(Map<String, dynamic>? json) => json == null
      ? const HotspotStatus()
      : HotspotStatus(
          active: json['active'] == true,
          ssid: json['ssid'] as String?,
          hasPassword: json['hasPassword'] == true,
        );

  /// A Wi-Fi QR only makes sense when we know the network's name.
  bool get canShowWifiQr => active && (ssid?.isNotEmpty ?? false);

  @override
  bool operator ==(Object other) =>
      other is HotspotStatus &&
      other.active == active &&
      other.ssid == ssid &&
      other.hasPassword == hasPassword;

  @override
  int get hashCode => Object.hash(active, ssid, hasPassword);
}

@immutable
class NetworkState {
  final NetworkMode mode;

  /// The host's pick for "both"; the other modes force their own.
  final QrTarget chosenTarget;
  final HotspotStatus hotspot;

  const NetworkState({
    this.mode = NetworkMode.local,
    this.chosenTarget = QrTarget.online,
    this.hotspot = const HotspotStatus(),
  });

  NetworkState copyWith({
    NetworkMode? mode,
    QrTarget? chosenTarget,
    HotspotStatus? hotspot,
  }) => NetworkState(
    mode: mode ?? this.mode,
    chosenTarget: chosenTarget ?? this.chosenTarget,
    hotspot: hotspot ?? this.hotspot,
  );

  bool get usesTunnel => mode != NetworkMode.local;
  bool get usesLan => mode != NetworkMode.online;

  /// Whether the QR shows a Local | Online switch.
  bool get canSwitchQr => mode == NetworkMode.both;
}

/// Drives the network mode for one server and decides which QR to show.
/// Lobby and overlay share it, so the QR switch stays in sync.
class NetworkModeService extends ValueNotifier<NetworkState> {
  static final Map<String, NetworkModeService> _instances = {};

  factory NetworkModeService.of(HostApiService api) =>
      _instances.putIfAbsent(api.baseUrl, () => NetworkModeService._(api));

  NetworkModeService._(this._api) : super(const NetworkState()) {
    _online.addListener(notifyListeners);
    _subscription = _api.connectAdminSocket().listen((event) {
      if (event['type'] == 'network_update' && event.containsKey('hotspot')) {
        _setHotspot(
          HotspotStatus.fromJson(event['hotspot'] as Map<String, dynamic>?),
        );
      }
    });
    unawaited(_restore());
  }

  final HostApiService _api;
  late final OnlineService _online = OnlineService.of(_api);
  late final AccessService _access = AccessService.of(_api);
  StreamSubscription? _subscription;

  OnlineService get online => _online;

  Future<void> _restore() async {
    final savedMode = await AppPreferences.networkMode();
    final savedTarget = await AppPreferences.qrTarget();
    value = value.copyWith(
      mode: NetworkMode.values.firstWhere(
        (m) => m.name == savedMode,
        orElse: () => NetworkMode.local,
      ),
      chosenTarget: QrTarget.values.firstWhere(
        (t) => t.name == savedTarget,
        orElse: () => QrTarget.online,
      ),
    );
    await _apply();
    await refreshHotspot();
  }

  /// Switches mode: starts or stops the tunnel and opens or closes the door
  /// to the local network. Turning the tunnel on points the QR at it.
  Future<void> setMode(NetworkMode mode) async {
    if (mode == value.mode) return;
    final tunnelWasOff = !value.usesTunnel;
    value = value.copyWith(mode: mode);
    await AppPreferences.setNetworkMode(mode.name);
    if (mode == NetworkMode.both && tunnelWasOff)
      await setQrTarget(QrTarget.online);
    await _apply();
  }

  Future<void> setQrTarget(QrTarget target) async {
    value = value.copyWith(chosenTarget: target);
    await AppPreferences.setQrTarget(target.name);
  }

  Future<void> _apply() async {
    await _access.setLanEnabled(value.usesLan);
    final state = _online.value.state;
    final running = state != OnlineState.off && state != OnlineState.error;
    if (value.usesTunnel && !running) {
      await _online.start();
    } else if (!value.usesTunnel && state != OnlineState.off) {
      await _online.stop();
    }
  }

  /// Retries the tunnel after an error.
  Future<void> retryTunnel() => _online.start();

  /// The QR to show right now. "Both" falls back to the local one while the
  /// tunnel isn't up yet; "online" shows the tunnel (or nothing) only.
  QrTarget get effectiveTarget => switch (value.mode) {
    NetworkMode.local => QrTarget.local,
    NetworkMode.online => QrTarget.online,
    NetworkMode.both =>
      _online.value.isOnline ? value.chosenTarget : QrTarget.local,
  };

  /// The tunnel as a connection when the QR points at it.
  ConnectionInfo? get onlineConnection =>
      effectiveTarget == QrTarget.online ? _online.value.connection : null;

  /// Whether to show the hotspot Wi-Fi QR next to the local one.
  bool get showWifiQr =>
      effectiveTarget == QrTarget.local && value.hotspot.canShowWifiQr;

  /// The network name rides along so a new hotspot name skips the cache.
  String get wifiQrUrl {
    final uri = AdminAuth.withToken(
      Uri.parse('${_api.baseUrl}/api/server/hotspot/qrcode'),
    );
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'ssid': value.hotspot.ssid ?? '',
          },
        )
        .toString();
  }

  Future<void> refreshHotspot() async {
    try {
      final response = await AdminAuth.client
          .get(Uri.parse('${_api.baseUrl}/api/server/hotspot'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        _setHotspot(
          HotspotStatus.fromJson(
            json.decode(response.body) as Map<String, dynamic>,
          ),
        );
      }
    } catch (e) {
      debugPrint('[NETWORK] hotspot status failed: $e');
    }
  }

  void _setHotspot(HotspotStatus hotspot) {
    if (hotspot != value.hotspot) value = value.copyWith(hotspot: hotspot);
  }

  @override
  void dispose() {
    _online.removeListener(notifyListeners);
    _subscription?.cancel();
    _instances.remove(_api.baseUrl);
    super.dispose();
  }
}
