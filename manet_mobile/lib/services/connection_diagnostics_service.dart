import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

enum ConnectionDiagnosticResult {
  hostOffline,      // Caso 1
  wifiChanged,      // Caso 2
  noWifi,           // Caso 3
  noInternet,       // Caso 4
  unknown,          // Caso 5
}

class ConnectionDiagnosticsService {
  ConnectionDiagnosticsService._();

  static final ConnectionDiagnosticsService instance =
      ConnectionDiagnosticsService._();

  Future<ConnectionDiagnosticResult> diagnoseDisconnection({
    required String hostIp,
    required int port,
    required String? expectedSsid,
    required bool isHttps,
  }) async {
    // 1. Check network connectivity status
    final List<ConnectivityResult> connectivity =
        await Connectivity().checkConnectivity();

    if (connectivity.isEmpty || connectivity.contains(ConnectivityResult.none)) {
      return ConnectionDiagnosticResult.noInternet; // Caso 4
    }

    // 2. Check if we are on local network (Wi-Fi or Ethernet)
    if (!connectivity.contains(ConnectivityResult.wifi) &&
        !connectivity.contains(ConnectivityResult.ethernet)) {
      return ConnectionDiagnosticResult.noWifi; // Caso 3
    }

    // 3. Check for Wi-Fi SSID change (only on Mobile if SSID is available)
    if (!kIsWeb) {
      try {
        final info = NetworkInfo();
        final currentSsidRaw = await info.getWifiName();
        if (currentSsidRaw != null && currentSsidRaw.isNotEmpty) {
          final currentSsid = currentSsidRaw.replaceAll('"', '');
          if (expectedSsid != null &&
              expectedSsid.isNotEmpty &&
              currentSsid != expectedSsid) {
            return ConnectionDiagnosticResult.wifiChanged; // Caso 2
          }
        }
      } catch (_) {
        // Location permission not granted or other platform errors, degrade gracefully
      }
    }

    // 4. Ping the server status endpoint via HTTP
    try {
      final scheme = isHttps ? 'https' : 'http';
      final url = Uri(
        scheme: scheme,
        host: hostIp,
        port: port,
        path: '/status',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['running'] == true) {
          // The host/server is actively running, so the reason is transient
          return ConnectionDiagnosticResult.unknown; // Caso 5
        }
      }
    } catch (_) {
      // HTTP request failed (refused/timeout) -> server is offline or host computer is shutdown
      return ConnectionDiagnosticResult.hostOffline; // Caso 1
    }

    return ConnectionDiagnosticResult.unknown; // Caso 5 fallback
  }

  /// Helper to get current Wi-Fi name (SSID), if available
  Future<String?> getCurrentWifiSsid() async {
    if (kIsWeb) return null;
    try {
      final info = NetworkInfo();
      final ssid = await info.getWifiName();
      if (ssid != null && ssid.isNotEmpty) {
        return ssid.replaceAll('"', '');
      }
    } catch (_) {}
    return null;
  }
}
