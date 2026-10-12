/// Mirrors the server's session state (manet_server/src/core/session_state.py).
enum SessionPhase { lobby, library, tournament, inGame }

SessionPhase _phaseFromWire(String? value) => switch (value) {
  'tournament' => SessionPhase.tournament,
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
  final bool overlayOpen;
  final int? overlayShotId;
  /// Player driving the overlay (null: anyone, e.g. opened by the host).
  final String? overlayOwner;
  /// False while a MaNet-launched game is not the foreground window; input
  /// is then paused so it can't leak into other games.
  final bool gameInFront;
  final TournamentState? tournament;
  final double matchSeconds;

  const SessionSnapshot({
    this.phase = SessionPhase.lobby,
    this.menuInput = false,
    this.focused = false,
    this.players = const [],
    this.allReady = false,
    this.countdown,
    this.runningGame,
    this.lastError,
    this.overlayOpen = false,
    this.overlayShotId,
    this.overlayOwner,
    this.gameInFront = true,
    this.tournament,
    this.matchSeconds = 10,
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
      overlayOpen: json['overlayOpen'] == true,
      overlayShotId: json['overlayShotId'] as int?,
      overlayOwner: json['overlayOwner'] as String?,
      gameInFront: json['gameInFront'] != false,
      tournament: json['tournament'] == null
          ? null
          : TournamentState.fromJson(json['tournament'] as Map<String, dynamic>),
      matchSeconds: (json['matchSeconds'] as num?)?.toDouble() ?? 10,
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
  final String description;
  /// Genre / category labels, e.g. "Corrida", "Co-op local".
  final List<String> tags;
  final String trailerUrl;
  /// When it was added to the library (seconds since epoch; small numbers
  /// for games saved before this field existed).
  final double addedAt;

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
    this.description = '',
    this.tags = const [],
    this.trailerUrl = '',
    this.addedAt = 0,
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
    description: json['description'] as String? ?? '',
    tags: [
      for (final tag in json['tags'] as List<dynamic>? ?? const [])
        tag.toString(),
    ],
    trailerUrl: json['trailerUrl'] as String? ?? '',
    addedAt: (json['addedAt'] as num?)?.toDouble() ?? 0,
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
    'description': description,
    'tags': tags,
    'trailerUrl': trailerUrl,
    if (addedAt > 0) 'addedAt': addedAt,
  };
}


class TournamentMatch {
  final String? a;
  final String? b;
  final String? winner;
  final int votesA;
  final int votesB;

  const TournamentMatch({this.a, this.b, this.winner, this.votesA = 0, this.votesB = 0});

  bool get isBye => a != null && b == null && winner != null;

  factory TournamentMatch.fromJson(Map<String, dynamic> json) => TournamentMatch(
    a: json['a'] as String?,
    b: json['b'] as String?,
    winner: json['winner'] as String?,
    votesA: json['votesA'] as int? ?? 0,
    votesB: json['votesB'] as int? ?? 0,
  );
}

class TournamentResult {
  final String winner;
  final String loser;
  final String side; // 'a' | 'b'
  final bool drawn;

  const TournamentResult({
    required this.winner,
    required this.loser,
    required this.side,
    required this.drawn,
  });
}

/// Elimination tournament between the games voted in the library
/// (server: manet_server/src/core/tournament.py).
class TournamentState {
  /// intro | match | result | champion
  final String stage;
  final List<List<TournamentMatch>> rounds;
  final int round;
  final int match;
  /// deviceId -> 'a' | 'b'
  final Map<String, String> votes;
  final DateTime? endsAt;
  final TournamentResult? result;
  final String? champion;

  const TournamentState({
    required this.stage,
    required this.rounds,
    required this.round,
    required this.match,
    required this.votes,
    this.endsAt,
    this.result,
    this.champion,
  });

  TournamentMatch? get current =>
      match >= 0 && round < rounds.length && match < rounds[round].length
          ? rounds[round][match]
          : null;

  /// Every game in the bracket, in first-round order.
  List<String> get entrants => [
    for (final m in rounds.isEmpty ? const <TournamentMatch>[] : rounds.first) ...[
      if (m.a != null) m.a!,
      if (m.b != null) m.b!,
    ],
  ];

  factory TournamentState.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>?;
    final endsAt = json['endsAt'] as num?;
    return TournamentState(
      stage: json['stage'] as String? ?? 'intro',
      rounds: [
        for (final round in json['rounds'] as List<dynamic>? ?? const [])
          [
            for (final m in round as List<dynamic>)
              TournamentMatch.fromJson(m as Map<String, dynamic>),
          ],
      ],
      round: json['round'] as int? ?? 0,
      match: json['match'] as int? ?? -1,
      votes: {
        for (final e in (json['votes'] as Map<String, dynamic>? ?? const {}).entries)
          e.key: e.value as String,
      },
      endsAt: endsAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((endsAt * 1000).round()),
      result: result == null
          ? null
          : TournamentResult(
              winner: result['winner'] as String,
              loser: result['loser'] as String,
              side: result['side'] as String? ?? 'a',
              drawn: result['drawn'] == true,
            ),
      champion: json['champion'] as String?,
    );
  }
}
