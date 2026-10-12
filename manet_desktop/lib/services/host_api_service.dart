import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:manet_desktop/models/controller_branding.dart';
import 'package:manet_desktop/models/player_face.dart';
import 'package:manet_desktop/models/session_models.dart';
import 'package:manet_desktop/theme/app_theme.dart';
import 'package:manet_desktop/services/admin_socket_service.dart';
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
  final double? reservedUntil;

  DeviceModel({
    required this.id,
    required this.name,
    required this.color,
    this.type,
    required this.connected,
    required this.face,
    this.reservedUntil,
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
      reservedUntil: (json['reservedUntil'] as num?)?.toDouble(),
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
  final String rightLayoutMode;
  final Map<String, int> buttonSizes;

  ControllerPresetLayout({
    required this.movementMode,
    required this.visibleButtons,
    required this.buttonOrder,
    required this.rightLayoutMode,
    required this.buttonSizes,
  });

  factory ControllerPresetLayout.fromJson(Map<String, dynamic> json) {
    final rawVisibility =
        json['visibleButtons'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final rawSizes =
        json['buttonSizes'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    final Map<String, int> buttonSizes = {};
    rawSizes.forEach((key, value) {
      if (value is num) {
        buttonSizes[key] = value.toInt();
      }
    });

    return ControllerPresetLayout(
      movementMode: json['movementMode'] as String? ?? 'floatingJoystick',
      visibleButtons: ControllerBranding.normalizeVisibility(rawVisibility),
      buttonOrder: ControllerBranding.normalizeCanonicalOrder(
        json['buttonOrder'] as List<dynamic>? ?? const [],
      ),
      rightLayoutMode: json['rightLayoutMode'] as String? ?? 'columns',
      buttonSizes: buttonSizes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'movementMode': movementMode,
      'visibleButtons': visibleButtons,
      'buttonOrder': buttonOrder,
      'rightLayoutMode': rightLayoutMode,
      'buttonSizes': buttonSizes,
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

class ControllerDeviceInfo {
  final String name;
  final String instanceId;
  final String api; // 'xinput' | 'dinput'
  final String origin; // 'vigem' | 'steam' | 'physical'
  final String vendor; // 'xbox' | 'playstation' | 'nintendo' | 'steam' | 'generic'
  final bool own; // one of this server's virtual pads

  ControllerDeviceInfo.fromJson(Map<String, dynamic> json)
    : own = json['own'] == true,
      name = json['name'] as String? ?? '',
      instanceId = json['instanceId'] as String? ?? '',
      api = json['api'] as String? ?? 'dinput',
      origin = json['origin'] as String? ?? 'physical',
      vendor = json['vendor'] as String? ?? 'generic';
}

class XinputSlotInfo {
  final int index;
  final String owner; // 'manet' | 'other' | 'free'
  final int? slot;

  XinputSlotInfo.fromJson(Map<String, dynamic> json)
    : index = json['index'] as int? ?? 0,
      owner = json['owner'] as String? ?? 'free',
      slot = json['slot'] as int?;
}

class OwnPadInfo {
  final int slot;
  final String type;
  final String? playerName;
  final int? xinputIndex;

  OwnPadInfo.fromJson(Map<String, dynamic> json)
    : slot = json['slot'] as int? ?? 0,
      type = json['type'] as String? ?? 'x360',
      playerName = json['playerName'] as String?,
      xinputIndex = json['xinputIndex'] as int?;
}

/// What Windows sees as game controllers, next to what MaNet created.
class ControllerInventory {
  final String? controllerMode;
  final List<OwnPadInfo> ownPads;
  final List<XinputSlotInfo> xinputSlots;
  final List<ControllerDeviceInfo> devices;
  final int foreignVirtual;
  final int physical;
  final int steam;
  final int playersWithoutXinput;
  final int otherServers;

  ControllerInventory.fromJson(Map<String, dynamic> json)
    : controllerMode = json['controllerMode'] as String?,
      ownPads = _list(json['ownPads'], OwnPadInfo.fromJson),
      xinputSlots = _list(json['xinputSlots'], XinputSlotInfo.fromJson),
      devices = _list(json['devices'], ControllerDeviceInfo.fromJson),
      foreignVirtual = _summary(json, 'foreignVirtual'),
      physical = _summary(json, 'physical'),
      steam = _summary(json, 'steam'),
      playersWithoutXinput = _summary(json, 'playersWithoutXinput'),
      otherServers = (json['otherServers'] as List<dynamic>? ?? const []).length;

  /// Something the host should look at: pads MaNet doesn't control are taking
  /// XInput slots, or players got no XInput slot at all.
  bool get hasConflicts =>
      foreignVirtual > 0 || playersWithoutXinput > 0 || otherServers > 0;

  bool get hasOtherControllers => foreignVirtual + physical + steam > 0;

  static List<T> _list<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) parse,
  ) {
    return (raw as List<dynamic>? ?? const [])
        .map((item) => parse(item as Map<String, dynamic>))
        .toList();
  }

  static int _summary(Map<String, dynamic> json, String key) {
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};
    return summary[key] as int? ?? 0;
  }
}

class HostApiService {
  // Every call has a deadline so a busy/frozen server surfaces as an error
  // instead of a spinner that never ends.
  static const Duration _requestTimeout = Duration(seconds: 5);
  static const Duration _resetTimeout = Duration(seconds: 20);

  final String baseUrl;

  HostApiService({required String host, required int port})
    : baseUrl = 'http://$host:$port';

  Future<AssignementStat> fetchSlots() async {
    final response = await http.get(Uri.parse('$baseUrl/api/slots')).timeout(_requestTimeout);
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
    ).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to assign device');
    }
  }

  Future<void> moveDevice(int fromSlot, int toSlot) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/slots/move'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'fromSlot': fromSlot, 'toSlot': toSlot}),
    ).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to move device');
    }
  }

  Future<void> swapDevices(int slotA, int slotB) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/slots/swap'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'slotA': slotA, 'slotB': slotB}),
    ).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to swap devices');
    }
  }

  Future<void> unassignDevice(int slotIndex) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/slots/unassign'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'slotIndex': slotIndex}),
    ).timeout(_requestTimeout);
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
    ).timeout(_resetTimeout);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to reset controllers (HTTP ${response.statusCode})',
      );
    }
  }

  // ------------------------------------------------------------- session

  Future<http.Response> _postJson(String path, [Map<String, dynamic>? body]) {
    return http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body ?? const {}),
        )
        .timeout(_requestTimeout);
  }

  Future<SessionSnapshot> fetchSession() async {
    final response =
        await http.get(Uri.parse('$baseUrl/api/session')).timeout(_requestTimeout);
    if (response.statusCode != 200) throw Exception('Failed to fetch session');
    return SessionSnapshot.fromJson(json.decode(response.body));
  }

  /// Tells the server whether the MaNet window is in front; while it is,
  /// phone input drives the menus instead of the virtual gamepads.
  Future<void> setSessionFocus(bool focused) =>
      _postJson('/api/session/focus', {'focused': focused});

  Future<void> setSessionPhase(String phase) =>
      _postJson('/api/session/phase', {'phase': phase});

  Future<void> vote(String deviceId, String? gameId) =>
      _postJson('/api/session/vote', {'deviceId': deviceId, 'gameId': gameId});

  /// Host confirmation: counts down and starts [gameId] (or the most voted).
  Future<void> playGame([String? gameId]) =>
      _postJson('/api/session/play', {'gameId': gameId});

  Future<void> cancelCountdown() => _postJson('/api/session/cancel-countdown');

  Future<void> stopGame() => _postJson('/api/session/stop-game');

  Future<void> returnFromGame() => _postJson('/api/session/return');

  /// Shows/hides the in-game overlay (phones toggle it with Home).
  Future<void> setOverlay(bool open) =>
      _postJson('/api/session/overlay', {'open': open});

  /// Leaves the tournament and goes back to the library (votes kept).
  Future<void> cancelTournament() => _postJson('/api/session/cancel-tournament');

  /// Which field of the current duel a player's cursor is in (null: none).
  Future<void> tournamentVote(String deviceId, String? side) => _postJson(
    '/api/session/tournament-vote',
    {'deviceId': deviceId, 'side': side},
  );

  /// Seconds each tournament match lasts.
  Future<void> setMatchSeconds(int seconds) =>
      _postJson('/api/session/settings', {'matchSeconds': seconds});

  /// Asks the server to move MaNet's window onto the game's monitor.
  Future<void> placeOverlayWindow() => _postJson('/api/session/place-overlay');

  /// Asks the server to bring the running game's window to the front.
  Future<void> focusGame() => _postJson('/api/session/focus-game');

  /// Close the running game and go back to picking one.
  Future<void> switchGame() => _postJson('/api/session/switch-game');

  /// Screenshot of the game taken when the overlay opened; [shotId] busts
  /// the image cache between openings.
  String overlayShotUrl(int shotId) =>
      '$baseUrl/api/session/overlay-shot?v=$shotId';

  Future<List<DisplayInfo>> fetchDisplays() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/displays'))
        .timeout(_requestTimeout);
    if (response.statusCode != 200) throw Exception('Failed to fetch displays');
    return (json.decode(response.body)['displays'] as List<dynamic>)
        .map((d) => DisplayInfo.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<List<GameEntry>> fetchGames() async {
    final response =
        await http.get(Uri.parse('$baseUrl/api/games')).timeout(_requestTimeout);
    if (response.statusCode != 200) throw Exception('Failed to fetch games');
    return _parseGames(json.decode(response.body)['games']);
  }

  static List<GameEntry> _parseGames(dynamic raw) => (raw as List<dynamic>? ?? const [])
      .map((g) => GameEntry.fromJson(g as Map<String, dynamic>))
      .toList();

  static List<GameEntry> parseGamesEvent(Map<String, dynamic> event) =>
      _parseGames(event['games']);

  Future<GameEntry> saveGame(GameEntry game) async {
    final uri = Uri.parse(
      game.id.isEmpty ? '$baseUrl/api/games' : '$baseUrl/api/games/${game.id}',
    );
    final body = json.encode(game.toJson());
    const headers = {'Content-Type': 'application/json'};
    final response = await (game.id.isEmpty
            ? http.post(uri, headers: headers, body: body)
            : http.put(uri, headers: headers, body: body))
        .timeout(_requestTimeout);
    if (response.statusCode != 200) throw Exception('Failed to save game');
    return GameEntry.fromJson(json.decode(response.body)['game']);
  }

  Future<void> deleteGame(String gameId) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/api/games/$gameId'))
        .timeout(_requestTimeout);
    if (response.statusCode != 200) throw Exception('Failed to delete game');
  }

  Future<ControllerInventory> fetchControllerInventory() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/controllers/inventory'))
        .timeout(_requestTimeout);
    if (response.statusCode == 200) {
      return ControllerInventory.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to fetch controller inventory');
  }

  /// Unplugs and recreates MaNet's virtual pads; players keep their slots.
  Future<void> recreateControllers() async {
    final response = await http
        .post(Uri.parse('$baseUrl/api/controllers/recreate'))
        .timeout(_resetTimeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to recreate controllers');
    }
  }

  /// Closes other MaNet server processes; returns how many were closed.
  Future<int> closeStaleServers() async {
    final response = await http
        .post(Uri.parse('$baseUrl/api/controllers/close-stale-servers'))
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to close stale servers');
    }
    final body = json.decode(response.body) as Map<String, dynamic>;
    return body['closed'] as int? ?? 0;
  }

  Future<Map<String, dynamic>> getServerStatus() async {
    final response = await http.get(Uri.parse('$baseUrl/api/server/status')).timeout(_requestTimeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get server status');
    }
  }

  /// Shared, auto-reconnecting admin event stream for this server.
  Stream<Map<String, dynamic>> connectAdminSocket() {
    return AdminSocketService.forBaseUrl(baseUrl).events;
  }

  Future<ConnectionSnapshot> fetchConnections() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/server/connections'),
    ).timeout(_requestTimeout);

    if (response.statusCode == 200) {
      return ConnectionSnapshot.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch connections');
    }
  }

  Future<DiagnosticsSnapshot> fetchDiagnostics() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/server/diagnostics'),
    ).timeout(_requestTimeout);

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
    ).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to run diagnostics action');
    }
  }

  Future<ConnectionInfo> selectConnection(String connectionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/server/connections/select'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'connectionId': connectionId}),
    ).timeout(_requestTimeout);

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
    ).timeout(_requestTimeout);

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
    final response =
        await http.get(Uri.parse('$baseUrl/api/presets?format=catalog')).timeout(_requestTimeout);

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
    ).timeout(_requestTimeout);

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
    ).timeout(_requestTimeout);

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
    ).timeout(_requestTimeout);

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
    ).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to delete preset');
    }
  }
}
