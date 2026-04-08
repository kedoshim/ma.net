import 'dart:convert';
import 'package:http/http.dart' as http;
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

  DeviceModel({required this.id, required this.name, required this.color, this.type});

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['deviceId'],
      name: json['name'] ?? json['deviceId'],
      color: json['color'] != null ? colorFromHex(json['color']) : AppTheme.primaryText,
      type: json['type'],
    );
  }
}

class SlotState {
  final List<DeviceModel> pool;
  final List<DeviceModel?> slots;

  SlotState({required this.pool, required this.slots});

  factory SlotState.fromJson(Map<String, dynamic> json) {
    List<DeviceModel> pool = (json['pool'] as List<dynamic>? ?? [])
        .map((d) => DeviceModel.fromJson(d))
        .toList();
    List<DeviceModel?> slots = (json['slots'] as List<dynamic>? ?? [])
        .map(
          (s) => s['device'] != null ? DeviceModel.fromJson(s['device']) : null,
        )
        .toList();
    return SlotState(pool: pool, slots: slots);
  }
}

class ConnectionInfo {
  final String url;
  final String wsUrl;

  ConnectionInfo({
    required this.url,
    required this.wsUrl,
  });

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) {
    return ConnectionInfo(
      url: json['url'],
      wsUrl: json['wsUrl'],
    );
  }
}

class HostApiService {
  final String baseUrl;

  HostApiService({
    required String host,
    required int port,
  }) : baseUrl = 'http://$host:$port';

  Future<SlotState> fetchSlots() async {
    final response = await http.get(Uri.parse('$baseUrl/api/slots'));
    if (response.statusCode == 200) {
      print("Response: ${response.body}");
      return SlotState.fromJson(json.decode(response.body));
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

  Stream<SlotState> connectAdminSocket() {
    final httpUri = Uri.parse(baseUrl);

    final wsUri = httpUri.replace(
      scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/admin',
    );

    final channel = WebSocketChannel.connect(wsUri);

    return channel.stream.map((message) {
      final data = json.decode(message);

      if (data['type'] == 'slot_update') {
        return SlotState.fromJson(data['data']);
      }

      throw Exception('Unknown message type');
    });
  }

  Future<ConnectionInfo> fetchConnectionInfo() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/server/connection'),
    );

    if (response.statusCode == 200) {
      return ConnectionInfo.fromJson(
        json.decode(response.body),
      );
    } else {
      throw Exception('Failed to fetch connection info');
    }
  }

  String getQrCodeUrl() {
    return '$baseUrl/api/server/qrcode';
  }
}
