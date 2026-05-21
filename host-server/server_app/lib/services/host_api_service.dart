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
  final String id;
  final String url;
  final String wsUrl;
  final String ip;
  final String displayNameKey;
  final String kind;
  final bool recommended;
  final bool selected;
  final bool preferred;
  final bool lastSuccessful;

  ConnectionInfo({
    required this.id,
    required this.url,
    required this.wsUrl,
    required this.ip,
    required this.displayNameKey,
    required this.kind,
    required this.recommended,
    required this.selected,
    required this.preferred,
    required this.lastSuccessful,
  });

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) {
    return ConnectionInfo(
      id: json['id'] ?? 'default',
      url: json['url'],
      wsUrl: json['wsUrl'],
      ip: json['ip'] ?? '',
      displayNameKey: json['displayNameKey'] ?? 'connection_label_backup',
      kind: json['kind'] ?? 'unknown',
      recommended: json['recommended'] == true,
      selected: json['selected'] == true,
      preferred: json['preferred'] == true,
      lastSuccessful: json['lastSuccessful'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'wsUrl': wsUrl,
      'ip': ip,
      'displayNameKey': displayNameKey,
      'kind': kind,
      'recommended': recommended,
      'selected': selected,
      'preferred': preferred,
      'lastSuccessful': lastSuccessful,
    };
  }
}

class ConnectionSnapshot {
  final ConnectionInfo selectedConnection;
  final List<ConnectionInfo> connections;

  ConnectionSnapshot({
    required this.selectedConnection,
    required this.connections,
  });

  factory ConnectionSnapshot.fromJson(Map<String, dynamic> json) {
    final selectedJson =
        json['selectedConnection'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final list = (json['connections'] as List<dynamic>? ?? const [])
        .map((item) => ConnectionInfo.fromJson(item as Map<String, dynamic>))
        .toList();

    return ConnectionSnapshot(
      selectedConnection: ConnectionInfo.fromJson(selectedJson),
      connections: list,
    );
  }
}

class DiagnosticCheck {
  final String id;
  final String level;
  final String icon;
  final String titleKey;
  final String bodyKey;
  final List<String> actionIds;

  DiagnosticCheck({
    required this.id,
    required this.level,
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
    required this.actionIds,
  });

  factory DiagnosticCheck.fromJson(Map<String, dynamic> json) {
    return DiagnosticCheck(
      id: json['id'] ?? 'unknown_check',
      level: json['level'] ?? 'ok',
      icon: json['icon'] ?? 'info',
      titleKey: json['titleKey'] ?? 'diag_title_unknown',
      bodyKey: json['bodyKey'] ?? 'diag_body_unknown',
      actionIds: (json['actionIds'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .toList(),
    );
  }
}

class DiagnosticQuickAction {
  final String id;
  final String labelKey;
  final String icon;
  final String kind;

  DiagnosticQuickAction({
    required this.id,
    required this.labelKey,
    required this.icon,
    required this.kind,
  });

  factory DiagnosticQuickAction.fromJson(Map<String, dynamic> json) {
    return DiagnosticQuickAction(
      id: json['id'] ?? 'unknown_action',
      labelKey: json['labelKey'] ?? 'diag_action_unknown',
      icon: json['icon'] ?? 'help_outline',
      kind: json['kind'] ?? 'client',
    );
  }
}

class DiagnosticsSnapshot {
  final String health;
  final bool attentionNeeded;
  final int attentionCount;
  final int connectedClientCount;
  final List<DiagnosticCheck> checks;
  final List<DiagnosticQuickAction> quickActions;

  DiagnosticsSnapshot({
    required this.health,
    required this.attentionNeeded,
    required this.attentionCount,
    required this.connectedClientCount,
    required this.checks,
    required this.quickActions,
  });

  factory DiagnosticsSnapshot.fromJson(Map<String, dynamic> json) {
    return DiagnosticsSnapshot(
      health: json['health'] ?? 'healthy',
      attentionNeeded: json['attentionNeeded'] == true,
      attentionCount: json['attentionCount'] as int? ?? 0,
      connectedClientCount: json['connectedClientCount'] as int? ?? 0,
      checks: (json['checks'] as List<dynamic>? ?? const [])
          .map((item) => DiagnosticCheck.fromJson(item as Map<String, dynamic>))
          .toList(),
      quickActions: (json['quickActions'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                DiagnosticQuickAction.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
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

  Future<ConnectionSnapshot> fetchConnections() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/server/connections'),
    );

    if (response.statusCode == 200) {
      return ConnectionSnapshot.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch connections');
    }
  }

  Future<DiagnosticsSnapshot> fetchDiagnostics() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/server/diagnostics'),
    );

    if (response.statusCode == 200) {
      return DiagnosticsSnapshot.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch diagnostics');
    }
  }

  Future<void> runDiagnosticsAction(String actionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/server/diagnostics/actions'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'actionId': actionId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to run diagnostics action');
    }
  }

  Future<ConnectionInfo> selectConnection(String connectionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/server/connections/select'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'connectionId': connectionId}),
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body) as Map<String, dynamic>;
      final selectedConnection =
          body['selectedConnection'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      return ConnectionInfo.fromJson(selectedConnection);
    } else {
      throw Exception('Failed to select connection');
    }
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

  String getQrCodeUrl([String? connectionId]) {
    final uri = Uri.parse('$baseUrl/api/server/qrcode');
    if (connectionId == null || connectionId.isEmpty) {
      return uri.toString();
    }
    return uri.replace(queryParameters: {'id': connectionId}).toString();
  }
}
