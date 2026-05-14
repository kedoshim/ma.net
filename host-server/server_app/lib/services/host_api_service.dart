import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:server_app/models/player_face.dart';
import 'package:server_app/theme/app_theme.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';

Color colorFromHex(String hex) {
  final cleaned = hex.replaceAll('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}

class DeviceModel {
  final String id;
  final String name;
  final Color color;
  final String? type;
  final bool connected;
  final PlayerFaceData face;

  DeviceModel({
    required this.id,
    required this.name,
    required this.color,
    this.type,
    required this.connected,
    required this.face,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    final color = json['color'] != null
        ? colorFromHex(json['color'])
        : AppTheme.primaryText;
    return DeviceModel(
      id: json['deviceId'],
      name: json['name'] ?? json['deviceId'],
      color: color,
      type: json['type'],
      connected: json['connected'] != false,
      face: PlayerFaceData.fromJson(json, fallbackColor: color),
    );
  }
}

class SlotModel {
  final int slot;
  DeviceModel? device;
  final String? type;

  SlotModel({required this.slot, this.device, this.type});

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      slot: json['slot'],
      device: json['device'] != null
          ? DeviceModel.fromJson(json['device'])
          : null,
      type: json['type'],
    );
  }
}

class AssignementStat {
  final List<DeviceModel> pool;
  final List<SlotModel> slots;

  AssignementStat({required this.pool, required this.slots});

  factory AssignementStat.fromJson(Map<String, dynamic> json) {
    List<DeviceModel> pool = (json['pool'] as List<dynamic>? ?? [])
        .map((d) => DeviceModel.fromJson(d))
        .toList();
    List<SlotModel> slots = (json['slots'] as List<dynamic>? ?? [])
        .map((s) => SlotModel.fromJson(s))
        .toList();
    return AssignementStat(pool: pool, slots: slots);
  }
}

class ConnectionInfo {
  final String url;
  final String wsUrl;

  ConnectionInfo({required this.url, required this.wsUrl});

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) {
    return ConnectionInfo(url: json['url'], wsUrl: json['wsUrl']);
  }
}

class HostApiService {
  final String baseUrl;

  HostApiService({required String host, required int port})
    : baseUrl = 'http://$host:$port';

  Future<AssignementStat> fetchSlots() async {
    final response = await http.get(Uri.parse('$baseUrl/api/slots'));
    if (response.statusCode == 200) {
      return AssignementStat.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch slots');
    }
  }

  Future<void> assignDevice(String deviceId, int slotIndex) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/slots/assign'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'deviceId': deviceId, 'slotIndex': slotIndex}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to assign device');
    }
  }

  Future<void> moveDevice(int fromSlot, int toSlot) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/slots/move'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'fromSlot': fromSlot, 'toSlot': toSlot}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to move device');
    }
  }

  Future<void> swapDevices(int slotA, int slotB) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/slots/swap'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'slotA': slotA, 'slotB': slotB}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to swap devices');
    }
  }

  Future<void> unassignDevice(int slotIndex) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/slots/unassign'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'slotIndex': slotIndex}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to unassign device');
    }
  }

  Future<Map<String, dynamic>> getServerStatus() async {
    final response = await http.get(Uri.parse('$baseUrl/api/server/status'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get server status');
    }
  }

  Stream<Map<String, dynamic>> connectAdminSocket() {
    final httpUri = Uri.parse(baseUrl);

    final wsUri = httpUri.replace(
      scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/admin',
    );

    final channel = WebSocketChannel.connect(wsUri);

    return channel.stream.map((message) {
      return json.decode(message) as Map<String, dynamic>;
    });
  }

  Future<ConnectionInfo> fetchConnectionInfo() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/server/connection'),
    );

    if (response.statusCode == 200) {
      return ConnectionInfo.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch connection info');
    }
  }

  String getQrCodeUrl() {
    return '$baseUrl/api/server/qrcode';
  }
}
