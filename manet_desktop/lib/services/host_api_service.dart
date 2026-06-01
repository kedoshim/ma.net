import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:manet_desktop/models/controller_branding.dart';
import 'package:manet_desktop/models/player_face.dart';
import 'package:manet_desktop/theme/app_theme.dart';
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

class ControllerPresetLayout {
  final String movementMode;
  final Map<String, bool> visibleButtons;
  final List<String> buttonOrder;

  ControllerPresetLayout({
    required this.movementMode,
    required this.visibleButtons,
    required this.buttonOrder,
  });

  factory ControllerPresetLayout.fromJson(Map<String, dynamic> json) {
    final rawVisibility =
        json['visibleButtons'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    return ControllerPresetLayout(
      movementMode: json['movementMode'] as String? ?? 'floatingJoystick',
      visibleButtons: ControllerBranding.normalizeVisibility(rawVisibility),
      buttonOrder: ControllerBranding.normalizeCanonicalOrder(
        json['buttonOrder'] as List<dynamic>? ?? const [],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'movementMode': movementMode,
      'visibleButtons': visibleButtons,
      'buttonOrder': buttonOrder,
    };
  }
}

class ControllerPreset {
  final String id;
  final String name;
  final String description;
  final String bestFor;
  final String pros;
  final String cons;
  final String category;
  final bool isBuiltIn;
  final ControllerPresetLayout layout;

  ControllerPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.bestFor,
    required this.pros,
    required this.cons,
    required this.category,
    required this.isBuiltIn,
    required this.layout,
  });

  factory ControllerPreset.fromJson(Map<String, dynamic> json) {
    return ControllerPreset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Preset',
      description: json['description'] as String? ?? '',
      bestFor: json['bestFor'] as String? ?? '',
      pros: json['pros'] as String? ?? '',
      cons: json['cons'] as String? ?? '',
      category: json['category'] as String? ?? 'builtin',
      isBuiltIn: json['isBuiltIn'] == true,
      layout: ControllerPresetLayout.fromJson(
        json['layout'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'bestFor': bestFor,
      'pros': pros,
      'cons': cons,
      'category': category,
      'isBuiltIn': isBuiltIn,
      'layout': layout.toJson(),
    };
  }
}

class PresetCatalog {
  final String activePresetId;
  final ControllerPreset activePreset;
  final List<ControllerPreset> builtInPresets;
  final List<ControllerPreset> gamePresets;
  final List<ControllerPreset> customPresets;

  PresetCatalog({
    required this.activePresetId,
    required this.activePreset,
    required this.builtInPresets,
    required this.gamePresets,
    required this.customPresets,
  });

  factory PresetCatalog.fromJson(Map<String, dynamic> json) {
    List<ControllerPreset> parseList(String key) {
      return (json[key] as List<dynamic>? ?? const [])
          .map(
            (item) => ControllerPreset.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    return PresetCatalog(
      activePresetId: json['activePresetId'] as String? ?? '',
      activePreset: ControllerPreset.fromJson(
        json['activePreset'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      builtInPresets: parseList('builtInPresets'),
      gamePresets: parseList('gamePresets'),
      customPresets: parseList('customPresets'),
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

  /// Reset controllers mode without restarting the server.
  /// Server should implement `/api/server/reset-controllers` to recreate controllers
  /// and reassign existing players to the same slot indices.
  Future<void> resetControllers({String? mode, int? slots, bool? fixed, int? reservationTimeout}) async {
    final body = <String, dynamic>{};
    if (mode != null) body['mode'] = mode;
    if (slots != null) body['slots'] = slots;
    if (fixed != null) body['fixed'] = fixed;
    if (reservationTimeout != null) body['reservationTimeout'] = reservationTimeout;

    final response = await http.post(
      Uri.parse('$baseUrl/api/server/reset-controllers'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to reset controllers (HTTP ${response.statusCode})',
      );
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

  Future<PresetCatalog> fetchPresets() async {
    final response = await http.get(Uri.parse('$baseUrl/api/presets'));

    if (response.statusCode == 200) {
      return PresetCatalog.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to fetch presets');
  }

  Future<ControllerPreset> selectPreset(String presetId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/presets/select'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'presetId': presetId}),
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body) as Map<String, dynamic>;
      return ControllerPreset.fromJson(
        body['activePreset'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      );
    }
    throw Exception('Failed to select preset');
  }

  Future<ControllerPreset> createCustomPreset({
    required String name,
    required ControllerPresetLayout layout,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/presets/custom'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'layout': layout.toJson()}),
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body) as Map<String, dynamic>;
      return ControllerPreset.fromJson(
        body['preset'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      );
    }
    throw Exception('Failed to create preset');
  }

  Future<ControllerPreset> updateCustomPreset({
    required String presetId,
    required String name,
    required ControllerPresetLayout layout,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/presets/custom/$presetId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'layout': layout.toJson()}),
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body) as Map<String, dynamic>;
      return ControllerPreset.fromJson(
        body['preset'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      );
    }
    throw Exception('Failed to update preset');
  }

  Future<void> deleteCustomPreset(String presetId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/presets/custom/$presetId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete preset');
    }
  }
}
