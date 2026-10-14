import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../models/session_models.dart';
import '../utils/app_preferences.dart';
import '../utils/win32_focus.dart';
import 'host_api_service.dart';

/// Desktop side of the couch session: follows the server's session state and
/// game library, reports whether the MaNet window is in front, and gets the
/// window out of the way while a game runs (or in free mode).
class SessionController extends ChangeNotifier with WindowListener {
  SessionController(this._api);

  final HostApiService _api;

  HostApiService get api => _api;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  SessionSnapshot snapshot = const SessionSnapshot();
  List<GameEntry> games = const [];
  bool _windowFocused = true;
  bool _disposed = false;

  void start() {
    windowManager.addListener(this);
    _subscription = _api.connectAdminSocket().listen(
      _handleEvent,
      onError: (Object e) => debugPrint('[SESSION] admin socket error: $e'),
    );
    unawaited(_loadInitialState());
  }

  Future<void> _loadInitialState() async {
    try {
      _windowFocused = await windowManager.isFocused();
    } catch (_) {}
    unawaited(_reportFocus());
    try {
      final results = await Future.wait([
        _api.fetchSession(),
        _api.fetchGames(),
      ]);
      if (_disposed) return;
      _applySnapshot(results[0] as SessionSnapshot);
      games = results[1] as List<GameEntry>;
      notifyListeners();
      unawaited(_pushSettings());
    } catch (e) {
      debugPrint('[SESSION] initial load failed: $e');
    }
  }

  void _handleEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'session_update':
        _applySnapshot(SessionSnapshot.fromJson(event));
        notifyListeners();
      case 'games_update':
        games = HostApiService.parseGamesEvent(event);
        notifyListeners();
    }
  }

  void _applySnapshot(SessionSnapshot next) {
    final previousPhase = snapshot.phase;
    final previousOverlay = snapshot.overlayOpen;
    final previousReady = snapshot.gameReady;
    snapshot = next;
    GameEntry.seatsCanRotate = next.consoleMode;
    if (previousOverlay != next.overlayOpen) {
      unawaited(_onOverlayChanged(next.overlayOpen, next.phase));
    }
    // A restarted server forgets the focus state; tell it again.
    if (next.focused != _windowFocused) unawaited(_reportFocus());
    if (previousPhase != next.phase) {
      unawaited(_onPhaseChanged(previousPhase, next.phase));
    } else if (next.phase == SessionPhase.inGame &&
        !previousReady &&
        next.gameReady &&
        !next.overlayOpen) {
      // The game's window is up: hand it the screen and the focus.
      unawaited(_stepAsideSafely());
    }
  }

  Future<void> _onPhaseChanged(SessionPhase from, SessionPhase to) async {
    try {
      if (to == SessionPhase.inGame) {
        // Stay up with the loading screen until the game's window shows up;
        // then let the game have the screen (and the focus).
        if (snapshot.gameReady) await _stepAside(focusGame: true);
      } else if (from == SessionPhase.inGame) {
        await windowManager.restore();
        await windowManager.show();
        await AppPreferences.applyFullScreen();
        await windowManager.focus();
      }
    } catch (e) {
      debugPrint('[SESSION] window change failed: $e');
    }
  }

  Future<void> _stepAsideSafely() async {
    try {
      await _stepAside(focusGame: true);
    } catch (e) {
      debugPrint('[SESSION] window change failed: $e');
    }
  }

  /// The overlay is MaNet's own window brought over the game and kept on
  /// top; closing it hands the screen (and focus) back to the game.
  Future<void> _onOverlayChanged(bool open, SessionPhase phase) async {
    try {
      if (open) {
        await windowManager.restore();
        await windowManager.show();
        // Full screen must be off while the window moves, then is applied
        // again on the game's monitor.
        if (await windowManager.isFullScreen()) {
          await windowManager.setFullScreen(false);
          await Future.delayed(const Duration(milliseconds: 120));
        }
        try {
          await _api.placeOverlayWindow();
        } catch (e) {
          debugPrint('[SESSION] could not move overlay to the game monitor: $e');
        }
        await windowManager.setAlwaysOnTop(true);
        await AppPreferences.applyFullScreen();
        await windowManager.focus();
      } else {
        await windowManager.setAlwaysOnTop(false);
        if (phase == SessionPhase.inGame) await _stepAside(focusGame: true);
      }
    } catch (e) {
      debugPrint('[SESSION] overlay window change failed: $e');
    }
  }

  /// Gets MaNet out of the game's way. window_manager refuses to minimize a
  /// full screen window, so full screen is dropped first (it comes back when
  /// MaNet shows up again).
  ///
  /// With [focusGame], MaNet hands the focus to the game window *before*
  /// minimizing: Windows always lets the foreground app do that, while
  /// minimizing first would activate whatever window is next in line and
  /// lock the game out. The server's focus call is only the fallback.
  Future<void> _stepAside({bool focusGame = false}) async {
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
      // Let the style change land before minimizing.
      await Future.delayed(const Duration(milliseconds: 120));
    }
    var focused = false;
    if (focusGame) {
      allowForegroundHandOff();
      try {
        final hwnd = await _api.gameWindow();
        if (hwnd != null) focused = focusWindow(hwnd);
      } catch (e) {
        debugPrint('[SESSION] could not get the game window: $e');
      }
    }
    await windowManager.minimize();
    if (focusGame && !focused) {
      try {
        await _api.focusGame();
      } catch (e) {
        debugPrint('[SESSION] could not focus the game: $e');
      }
    }
  }

  Future<void> _reportFocus() async {
    try {
      await _api.setSessionFocus(_windowFocused);
    } catch (e) {
      debugPrint('[SESSION] focus report failed: $e');
    }
  }

  void _setWindowFocused(bool focused) {
    if (_windowFocused == focused) return;
    _windowFocused = focused;
    unawaited(_reportFocus());
  }

  @override
  void onWindowFocus() => _setWindowFocused(true);

  @override
  void onWindowBlur() => _setWindowFocused(false);

  @override
  void onWindowMinimize() => _setWindowFocused(false);

  // ------------------------------------------------------------ queries

  SessionPlayer? playerById(String deviceId) {
    for (final player in snapshot.players) {
      if (player.deviceId == deviceId) return player;
    }
    return null;
  }

  bool isReady(String deviceId) => playerById(deviceId)?.ready ?? false;

  List<String> votersFor(String gameId) => [
    for (final p in snapshot.players)
      if (p.vote == gameId) p.deviceId,
  ];

  GameEntry? gameById(String? id) {
    if (id == null) return null;
    for (final game in games) {
      if (game.id == id) return game;
    }
    return null;
  }

  // ------------------------------------------------------------ intents

  Future<void> openLibrary() => _api.setSessionPhase('library');
  Future<void> backToLobby() => _api.setSessionPhase('lobby');
  Future<void> vote(String deviceId, String? gameId) =>
      _api.vote(deviceId, gameId);
  Future<void> play([String? gameId]) => _api.playGame(gameId);
  Future<void> cancelCountdown() => _api.cancelCountdown();
  Future<void> stopGame() => _api.stopGame();
  Future<void> markGameReady() => _api.markGameReady();
  Future<void> returnFromGame() => _api.returnFromGame();
  Future<void> setOverlay(bool open) => _api.setOverlay(open);
  Future<void> cancelTournament() => _api.cancelTournament();
  Future<void> setLobbyZone(String deviceId, bool inside) =>
      _api.setLobbyZone(deviceId, inside);
  Future<void> setLineupZone(String deviceId, String? zone) =>
      _api.setLineupZone(deviceId, zone);
  Future<void> cancelLineup() => _api.cancelLineup();
  Future<void> tournamentVote(String deviceId, String? side) =>
      _api.tournamentVote(deviceId, side);
  Future<void> enterFreeMode() => _api.enterFreeMode();
  Future<void> showDetails(String deviceId, String? gameId) =>
      _api.showDetails(deviceId, gameId);
  Future<void> requestLobby(String deviceId) => _api.requestLobby(deviceId);

  Future<void> setFreeModeEnabled(bool enabled) async {
    await AppPreferences.setFreeModeEnabled(enabled);
    await _api.setFreeModeEnabled(enabled);
  }

  /// Tool mode always offers free mode (the "Modo livre" game card).
  Future<void> setConsoleMode(bool enabled) async {
    await AppPreferences.setConsoleMode(enabled);
    await _api.setConsoleMode(enabled);
    if (!enabled) {
      await AppPreferences.setFreeModeEnabled(true);
      await _api.setFreeModeEnabled(true);
    }
  }

  Future<void> setMousePassword(String password) async {
    await AppPreferences.setMousePassword(password);
    await _api.setMousePassword(password.trim());
  }

  Future<void> setLobbyStartRule(String rule) async {
    await AppPreferences.setLobbyStartRule(rule);
    await _api.setLobbyStartRule(rule);
  }

  Future<void> setMatchSeconds(int seconds) async {
    await AppPreferences.setMatchSeconds(seconds);
    await _api.setMatchSeconds(seconds);
  }

  /// The server doesn't keep settings between runs: push the saved ones.
  Future<void> _pushSettings() async {
    try {
      final seconds = await AppPreferences.matchSeconds();
      if (seconds != snapshot.matchSeconds.round()) {
        await _api.setMatchSeconds(seconds);
      }
      // The server doesn't echo the password: always push it.
      await _api.setMousePassword(await AppPreferences.mousePassword());
      final rule = await AppPreferences.lobbyStartRule();
      if (rule != snapshot.lobbyStartRule) {
        await _api.setLobbyStartRule(rule);
      }
      final consoleMode = await AppPreferences.consoleMode();
      if (consoleMode != snapshot.consoleMode) {
        await _api.setConsoleMode(consoleMode);
      }
      final freeMode = !consoleMode || await AppPreferences.freeModeEnabled();
      if (freeMode != snapshot.freeModeEnabled) {
        await _api.setFreeModeEnabled(freeMode);
      }
    } catch (e) {
      debugPrint('[SESSION] settings push failed: $e');
    }
  }
  Future<void> switchGame() => _api.switchGame();
  Future<GameEntry> saveGame(GameEntry game) => _api.saveGame(game);
  Future<void> deleteGame(String id) => _api.deleteGame(id);

  @override
  void dispose() {
    _disposed = true;
    windowManager.removeListener(this);
    _subscription?.cancel();
    super.dispose();
  }
}
