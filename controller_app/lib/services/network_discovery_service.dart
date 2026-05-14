import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class DiscoveredHost {
  final String ip;
  final int port;
  final String name;

  DiscoveredHost({required this.ip, required this.port, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredHost &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;
}

class NetworkDiscoveryService {
  final int targetPort;
  bool _isScanning = false;
  Timer? _periodicScanTimer;

  final StreamController<List<DiscoveredHost>> _hostsController =
      StreamController<List<DiscoveredHost>>.broadcast();
  Stream<List<DiscoveredHost>> get discoveredHosts => _hostsController.stream;

  final Set<DiscoveredHost> _foundHosts = {};

  NetworkDiscoveryService({this.targetPort = 8765});

  void startScanning() {
    if (_isScanning) return;
    _isScanning = true;
    _foundHosts.clear();
    _hostsController.add([]);

    _scanNetwork();

    // Periodically re-scan the network every 10 seconds to catch newly started servers
    _periodicScanTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _scanNetwork();
    });
  }

  void forceRefresh() {
    if (!_isScanning) return;
    _foundHosts.clear();
    if (!_hostsController.isClosed) {
      _hostsController.add([]);
    }
    _scanNetwork();
  }

  void stopScanning() {
    _isScanning = false;
    _periodicScanTimer?.cancel();
    if (!_hostsController.isClosed) {
      _hostsController.close();
    }
  }

  Future<void> _scanNetwork() async {
    if (kIsWeb) return; // Cannot scan from a browser sandbox

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('127.')) continue;

          final parts = ip.split('.');
          if (parts.length != 4) continue;

          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
          _scanSubnet(subnet);
        }
      }
    } catch (e) {
      debugPrint('Discovery error: $e');
    }
  }

  void _scanSubnet(String subnet) {
    for (int i = 1; i <= 254; i++) {
      if (!_isScanning) break;
      final targetIp = '$subnet.$i';
      _checkHost(targetIp);
    }
  }

  Future<void> _checkHost(String ip) async {
    if (!_isScanning) return;
    try {
      // Native socket connection is the fastest way to verify an open port
      final socket = await Socket.connect(
        ip,
        targetPort,
        timeout: const Duration(milliseconds: 500),
      );
      socket.destroy();

      final host = DiscoveredHost(
        ip: ip,
        port: targetPort,
        name: 'ma•net Host',
      );
      if (!_foundHosts.contains(host)) {
        _foundHosts.add(host);
        if (_isScanning && !_hostsController.isClosed) {
          _hostsController.add(_foundHosts.toList());
        }
      }
    } catch (_) {}
  }
}
