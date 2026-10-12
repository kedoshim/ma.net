/// Mirrors the server's session state (manet_server/src/core/session_state.py).
enum SessionPhase { lobby, library, inGame }

SessionPhase _phaseFromWire(String? value) => switch (value) {
  'library' => SessionPhase.library,
  'in_game' => SessionPhase.inGame,
  _ => SessionPhase.lobby,
};

class SessionPlayer {
  final String deviceId;
  final int slot;
  final bool ready;
  final String? vote;

  const SessionPlayer({
    required this.deviceId,
    required this.slot,
    required this.ready,
    this.vote,
  });

  factory SessionPlayer.fromJson(Map<String, dynamic> json) => SessionPlayer(
    deviceId: json['deviceId'] as String? ?? '',
    slot: json['slot'] as int? ?? 0,
    ready: json['ready'] == true,
    vote: json['vote'] as String?,
  );
}

class SessionCountdown {
  final String gameId;
  final DateTime endsAt;
  final double seconds;

  const SessionCountdown({
    required this.gameId,
    required this.endsAt,
    required this.seconds,
  });
}

class RunningGameInfo {
  final String id;
  final String name;
  final bool tracked;

  const RunningGameInfo({
    required this.id,
    required this.name,
    required this.tracked,
  });
}

class SessionSnapshot {
  final SessionPhase phase;
  final bool menuInput;
  final bool focused;
  final List<SessionPlayer> players;
  final bool allReady;
  final SessionCountdown? countdown;
  final RunningGameInfo? runningGame;
  final String? lastError;

  const SessionSnapshot({
    this.phase = SessionPhase.lobby,
    this.menuInput = false,
    this.focused = false,
    this.players = const [],
    this.allReady = false,
    this.countdown,
    this.runningGame,
    this.lastError,
  });

  int get readyCount => players.where((p) => p.ready).length;

  factory SessionSnapshot.fromJson(Map<String, dynamic> json) {
    final countdown = json['countdown'] as Map<String, dynamic>?;
    final running = json['runningGame'] as Map<String, dynamic>?;
    return SessionSnapshot(
      phase: _phaseFromWire(json['phase'] as String?),
      menuInput: json['inputMode'] == 'menu',
      focused: json['focused'] == true,
      players: (json['players'] as List<dynamic>? ?? const [])
          .map((p) => SessionPlayer.fromJson(p as Map<String, dynamic>))
          .toList(),
      allReady: json['allReady'] == true,
      countdown: countdown == null
          ? null
          : SessionCountdown(
              gameId: countdown['gameId'] as String,
              endsAt: DateTime.fromMillisecondsSinceEpoch(
                ((countdown['endsAt'] as num) * 1000).round(),
              ),
              seconds: (countdown['seconds'] as num?)?.toDouble() ?? 3,
            ),
      runningGame: running == null
          ? null
          : RunningGameInfo(
              id: running['id'] as String? ?? '',
              name: running['name'] as String? ?? '',
              tracked: running['tracked'] == true,
            ),
      lastError: json['lastError'] as String?,
    );
  }
}

/// Per player-count override: e.g. 1-4 players x•input, 5-8 d•input.
class GameRule {
  final int minPlayers;
  final int maxPlayers;
  final String? controllerMode;
  final String? presetId;

  const GameRule({
    required this.minPlayers,
    required this.maxPlayers,
    this.controllerMode,
    this.presetId,
  });

  GameRule copyWith({
    int? minPlayers,
    int? maxPlayers,
    String? Function()? controllerMode,
    String? Function()? presetId,
  }) => GameRule(
    minPlayers: minPlayers ?? this.minPlayers,
    maxPlayers: maxPlayers ?? this.maxPlayers,
    controllerMode: controllerMode != null ? controllerMode() : this.controllerMode,
    presetId: presetId != null ? presetId() : this.presetId,
  );

  factory GameRule.fromJson(Map<String, dynamic> json) => GameRule(
    minPlayers: json['minPlayers'] as int? ?? 1,
    maxPlayers: json['maxPlayers'] as int? ?? 1,
    controllerMode: json['controllerMode'] as String?,
    presetId: json['presetId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'minPlayers': minPlayers,
    'maxPlayers': maxPlayers,
    'controllerMode': controllerMode,
    'presetId': presetId,
  };
}

/// A monitor the server can place games on (see /api/displays).
class DisplayInfo {
  final int index;
  final bool primary;
  final int width;
  final int height;

  const DisplayInfo({
    required this.index,
    required this.primary,
    required this.width,
    required this.height,
  });

  factory DisplayInfo.fromJson(Map<String, dynamic> json) => DisplayInfo(
    index: json['index'] as int? ?? 0,
    primary: json['primary'] == true,
    width: json['width'] as int? ?? 0,
    height: json['height'] as int? ?? 0,
  );
}

class GameEntry {
  final String id;
  final String name;
  final String path;
  final String arguments;
  final String workingDirectory;
  final String coverPath;
  final int minPlayers;
  final int maxPlayers;
  final String? presetId;
  final String? controllerMode;
  final List<GameRule> rules;
  final int? display;
  final bool fullscreen;

  const GameEntry({
    this.id = '',
    required this.name,
    required this.path,
    this.arguments = '',
    this.workingDirectory = '',
    this.coverPath = '',
    this.minPlayers = 1,
    this.maxPlayers = 4,
    this.presetId,
    this.controllerMode,
    this.rules = const [],
    this.display,
    this.fullscreen = true,
  });

  bool fits(int players) => players >= minPlayers && players <= maxPlayers;

  factory GameEntry.fromJson(Map<String, dynamic> json) => GameEntry(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    path: json['path'] as String? ?? '',
    arguments: json['arguments'] as String? ?? '',
    workingDirectory: json['workingDirectory'] as String? ?? '',
    coverPath: json['coverPath'] as String? ?? '',
    minPlayers: json['minPlayers'] as int? ?? 1,
    maxPlayers: json['maxPlayers'] as int? ?? 4,
    presetId: json['presetId'] as String?,
    controllerMode: json['controllerMode'] as String?,
    rules: (json['rules'] as List<dynamic>? ?? const [])
        .map((r) => GameRule.fromJson(r as Map<String, dynamic>))
        .toList(),
    display: json['display'] as int?,
    fullscreen: json['fullscreen'] != false,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'arguments': arguments,
    'workingDirectory': workingDirectory,
    'coverPath': coverPath,
    'minPlayers': minPlayers,
    'maxPlayers': maxPlayers,
    'presetId': presetId,
    'controllerMode': controllerMode,
    'rules': [for (final rule in rules) rule.toJson()],
    'display': display,
    'fullscreen': fullscreen,
  };
}
