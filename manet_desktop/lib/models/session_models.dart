/// Mirrors the server's session state (manet_server/src/core/session_state.py).
enum SessionPhase { lobby, library, tournament, lineup, inGame }

SessionPhase _phaseFromWire(String? value) => switch (value) {
  'tournament' => SessionPhase.tournament,
  'lineup' => SessionPhase.lineup,
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

/// Everyone is ready in the lobby: the game selection opens at [endsAt].
class LobbyCountdown {
  final DateTime endsAt;
  final double seconds;

  const LobbyCountdown({required this.endsAt, required this.seconds});
}

/// A player asked to leave the game selection; the majority decides.
class LobbyRequest {
  final String fromDeviceId;
  final String fromName;
  final int yes;
  final int no;
  final int needed;

  const LobbyRequest({
    required this.fromDeviceId,
    required this.fromName,
    required this.yes,
    required this.no,
    required this.needed,
  });

  factory LobbyRequest.fromJson(Map<String, dynamic> json) {
    final from = json['from'] as Map<String, dynamic>? ?? const {};
    return LobbyRequest(
      fromDeviceId: from['deviceId'] as String? ?? '',
      fromName: from['name'] as String? ?? '',
      yes: json['yes'] as int? ?? 0,
      no: json['no'] as int? ?? 0,
      needed: json['needed'] as int? ?? 1,
    );
  }
}

/// Everyone left the running game: the overlay opened by itself with the QR
/// code; whoever comes back resumes or picks another game in its menu.
class AwayState {
  /// When the game closes if nobody comes back (null: never, or someone is
  /// connected).
  final DateTime? closeAt;

  const AwayState({this.closeAt});

  factory AwayState.fromJson(Map<String, dynamic> json) {
    final closeAt = json['closeAt'] as num?;
    return AwayState(
      closeAt: closeAt == null ? null : _fromEpochSeconds(closeAt),
    );
  }
}

DateTime _fromEpochSeconds(num seconds) =>
    DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());

/// Console mode: a game has fewer seats than players, so the group decides
/// who plays first (server: manet_server/src/core/lineup.py).
class LineupState {
  final String gameId;
  final int seats;
  /// choose | pick | reveal | done
  final String stage;
  final DateTime? endsAt;
  final List<String> queue;
  /// deviceId -> 'play' | 'bench' (null: in between).
  final Map<String, String?> zones;
  /// 'out': decided players sit out; 'in': they play.
  final String? mode;
  final int needed;
  final List<String> decided;
  final List<String> candidates;
  final int round;
  /// 'dedanha' | 'zerinho'
  final String? game;
  final List<String> picked;
  final Map<String, int>? picks;
  final Map<String, dynamic>? result;
  final List<String> chosen;
  final List<String> bench;

  const LineupState({
    required this.gameId,
    required this.seats,
    required this.stage,
    required this.endsAt,
    required this.queue,
    required this.zones,
    required this.mode,
    required this.needed,
    required this.decided,
    required this.candidates,
    required this.round,
    required this.game,
    required this.picked,
    required this.picks,
    required this.result,
    required this.chosen,
    required this.bench,
  });

  static List<String> _ids(dynamic raw) =>
      (raw as List<dynamic>? ?? const []).cast<String>();

  factory LineupState.fromJson(Map<String, dynamic> json) {
    final endsAt = json['endsAt'] as num?;
    final picks = json['picks'] as Map<String, dynamic>?;
    return LineupState(
      gameId: json['gameId'] as String? ?? '',
      seats: json['seats'] as int? ?? 1,
      stage: json['stage'] as String? ?? 'choose',
      endsAt: endsAt == null ? null : _fromEpochSeconds(endsAt),
      queue: _ids(json['queue']),
      zones: {
        for (final e in (json['zones'] as Map<String, dynamic>? ?? const {}).entries)
          e.key: e.value as String?,
      },
      mode: json['mode'] as String?,
      needed: json['needed'] as int? ?? 0,
      decided: _ids(json['decided']),
      candidates: _ids(json['candidates']),
      round: json['round'] as int? ?? 0,
      game: json['game'] as String?,
      picked: _ids(json['picked']),
      picks: picks == null ? null : {for (final e in picks.entries) e.key: e.value as int},
      result: json['result'] as Map<String, dynamic>?,
      chosen: _ids(json['chosen']),
      bench: _ids(json['bench']),
    );
  }
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
  /// False from a launch until the game's window shows up (loading screen).
  final bool gameReady;
  final DateTime? launchStartedAt;
  final TournamentState? tournament;
  final double matchSeconds;
  /// MaNet stepped aside: phones are plain gamepads for any game.
  final bool freeMode;
  final bool freeModeEnabled;
  /// Console mode (no slot settings, pads created per game) or tool mode.
  final bool consoleMode;
  /// Console mode: checked-in players in arrival order.
  final List<String> queue;
  /// Console lobby: 'majority' or 'all' must leave through the right edge.
  final String lobbyStartRule;
  /// Console lobby: checked-in players standing in the "play" area.
  final Set<String> playZone;
  final LineupState? lineup;
  final LobbyCountdown? lobbyCountdown;
  final LobbyRequest? lobbyRequest;
  /// deviceId -> gameId whose details that player reads on their phone.
  final Map<String, String> reading;
  /// Set while the game waits for its players (everyone left).
  final AwayState? away;
  /// Minutes an abandoned game waits before closing (0: never).
  final int abandonCloseMinutes;

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
    this.gameReady = true,
    this.launchStartedAt,
    this.tournament,
    this.matchSeconds = 10,
    this.freeMode = false,
    this.freeModeEnabled = true,
    this.consoleMode = false,
    this.queue = const [],
    this.lobbyStartRule = 'majority',
    this.playZone = const {},
    this.lineup,
    this.lobbyCountdown,
    this.lobbyRequest,
    this.reading = const {},
    this.away,
    this.abandonCloseMinutes = 30,
  });

  int get readyCount => players.where((p) => p.ready).length;

  factory SessionSnapshot.fromJson(Map<String, dynamic> json) {
    final countdown = json['countdown'] as Map<String, dynamic>?;
    final running = json['runningGame'] as Map<String, dynamic>?;
    final lobbyCountdown = json['lobbyCountdown'] as Map<String, dynamic>?;
    final lobbyRequest = json['lobbyRequest'] as Map<String, dynamic>?;
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
      gameReady: json['gameReady'] != false,
      launchStartedAt: json['launchStartedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              ((json['launchStartedAt'] as num) * 1000).round(),
            ),
      tournament: json['tournament'] == null
          ? null
          : TournamentState.fromJson(json['tournament'] as Map<String, dynamic>),
      matchSeconds: (json['matchSeconds'] as num?)?.toDouble() ?? 10,
      freeMode: json['freeMode'] == true,
      freeModeEnabled: json['freeModeEnabled'] != false,
      consoleMode: json['consoleMode'] == true,
      queue: (json['queue'] as List<dynamic>? ?? const []).cast<String>(),
      lobbyStartRule: json['lobbyStartRule'] == 'all' ? 'all' : 'majority',
      playZone: {...(json['playZone'] as List<dynamic>? ?? const []).cast<String>()},
      lineup: json['lineup'] == null
          ? null
          : LineupState.fromJson(json['lineup'] as Map<String, dynamic>),
      lobbyCountdown: lobbyCountdown == null
          ? null
          : LobbyCountdown(
              endsAt: _fromEpochSeconds(lobbyCountdown['endsAt'] as num),
              seconds: (lobbyCountdown['seconds'] as num?)?.toDouble() ?? 5,
            ),
      lobbyRequest: lobbyRequest == null ? null : LobbyRequest.fromJson(lobbyRequest),
      reading: {
        for (final e in (json['reading'] as Map<String, dynamic>? ?? const {}).entries)
          e.key: e.value as String,
      },
      away: json['away'] == null
          ? null
          : AwayState.fromJson(json['away'] as Map<String, dynamic>),
      abandonCloseMinutes: (json['abandonCloseMinutes'] as num?)?.toInt() ?? 30,
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
  /// When MaNet last launched it (seconds since epoch, 0: never).
  final double lastPlayedAt;
  /// How much the couch likes it lately, from the server's play history:
  /// each real play is worth 1, halving every two months. Read-only here.
  final double score;
  /// Image URLs shown on a player's phone with the details.
  final List<String> screenshots;
  /// Games played in the phone's browser (Jackbox): while the game runs the
  /// pad shows a button that opens this page. Empty: no button.
  final String phoneUrl;

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
    this.lastPlayedAt = 0,
    this.score = 0,
    this.screenshots = const [],
    this.phoneUrl = '',
  });

  /// Console mode: games with fewer seats than players fit too, a lineup
  /// decides who plays first. Kept in sync with the session by
  /// SessionController.
  static bool seatsCanRotate = false;

  bool fits(int players) =>
      players >= minPlayers && (seatsCanRotate || players <= maxPlayers);

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
    lastPlayedAt: (json['lastPlayedAt'] as num?)?.toDouble() ?? 0,
    score: (json['score'] as num?)?.toDouble() ?? 0,
    screenshots: [
      for (final url in json['screenshots'] as List<dynamic>? ?? const [])
        url.toString(),
    ],
    phoneUrl: json['phoneUrl'] as String? ?? '',
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
    if (lastPlayedAt > 0) 'lastPlayedAt': lastPlayedAt,
    'screenshots': screenshots,
    'phoneUrl': phoneUrl,
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
