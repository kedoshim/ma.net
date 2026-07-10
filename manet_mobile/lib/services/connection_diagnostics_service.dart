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
    debugPrint('[Diagnostic] Starting diagnosis. Host: $hostIp:$port, Expected SSID: $expectedSsid, HTTPS: $isHttps');

    // 1. Check network connectivity status
    final List<ConnectivityResult> connectivity =
        await Connectivity().checkConnectivity();
    debugPrint('[Diagnostic] Connectivity results: $connectivity');

    final bool isOffline = connectivity.isEmpty || connectivity.contains(ConnectivityResult.none);
    final bool hasLocalNetwork = connectivity.contains(ConnectivityResult.wifi) ||
                                 connectivity.contains(ConnectivityResult.ethernet);

    // If we had an expected SSID and we are no longer on a local network (Wi-Fi/Ethernet)
    if (expectedSsid != null && expectedSsid.isNotEmpty) {
      if (isOffline || !hasLocalNetwork) {
        debugPrint('[Diagnostic] Left expected Wi-Fi network (offline=$isOffline, localNetwork=$hasLocalNetwork) -> returning noWifi');
        return ConnectionDiagnosticResult.noWifi; // Caso 1
      }
    }

    if (isOffline) {
      debugPrint('[Diagnostic] Device is offline.');
      return ConnectionDiagnosticResult.noInternet; // Caso 4
    }

    if (!hasLocalNetwork) {
      debugPrint('[Diagnostic] Device connected but not on local network (Wi-Fi/Ethernet) -> returning noWifi');
      return ConnectionDiagnosticResult.noWifi; // Caso 3
    }

    // 2. Check for Wi-Fi SSID change (only on Mobile if SSID is available)
    if (!kIsWeb) {
      try {
        final info = NetworkInfo();
        final currentSsidRaw = await info.getWifiName();
        debugPrint('[Diagnostic] Raw current SSID from NetworkInfo: $currentSsidRaw');
        if (currentSsidRaw != null && currentSsidRaw.isNotEmpty) {
          final currentSsid = currentSsidRaw.replaceAll('"', '');
          debugPrint('[Diagnostic] Cleaned SSID: current="$currentSsid", expected="$expectedSsid"');
          if (expectedSsid != null &&
              expectedSsid.isNotEmpty &&
              currentSsid != expectedSsid) {
            debugPrint('[Diagnostic] SSID changed! wifiChanged.');
            return ConnectionDiagnosticResult.wifiChanged; // Caso 2
          }
        }
      } catch (e) {
        debugPrint('[Diagnostic] Error fetching current Wi-Fi name: $e');
        // Location permission not granted or other platform errors, degrade gracefully
      }
    } else {
      debugPrint('[Diagnostic] running on Web, skipping SSID check.');
    }

    // 3. Ping the server status endpoint via HTTP
    try {
      final scheme = isHttps ? 'https' : 'http';
      final url = Uri(
        scheme: scheme,
        host: hostIp,
        port: port,
        path: '/status',
      );
      debugPrint('[Diagnostic] Pinging host status endpoint: $url');
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      debugPrint('[Diagnostic] Host ping response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[Diagnostic] Host ping response body: $data');
        if (data is Map<String, dynamic> && data['running'] == true) {
          debugPrint('[Diagnostic] Server is up and running. Reason is unknown.');
          return ConnectionDiagnosticResult.unknown; // Caso 5
        }
      }
    } catch (e) {
      debugPrint('[Diagnostic] Ping to host failed (server offline or host down): $e');
      return ConnectionDiagnosticResult.hostOffline; // Caso 1 (Host desligado)
    }

    debugPrint('[Diagnostic] Reached end fallback -> unknown');
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
