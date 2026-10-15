import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/strings.dart';
import '../../models/session_models.dart';
import '../../services/host_api_service.dart';
import '../../services/session_controller.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../widgets/juicy_widgets.dart';
import '../../widgets/comic_burst.dart';
import '../../widgets/player_cursor.dart';
import '../../services/sound_effect_service.dart';
import '../home_page/gamepad_state.dart';
import 'library_browser.dart';
import 'manage_games_dialog.dart';
import '../../utils/app_preferences.dart';

export '../../widgets/player_cursor.dart' show PlayerCursor;

/// Game selection: every player steers an arrow with their face using the
/// left stick over a two-row strip of big game cards.
///
/// - Cursors near the left/right edge of the strip push it sideways; pushes
///   from both sides cancel out. It starts centered on the most recently
///   played games.
/// - Select (A) on a game sticks the player's face on it as their vote: the
///   cursor squashes into a sticker and stays there until Cancel (B).
/// - Info (X) on a game shows its details on that player's phone; while
///   reading, the cursor waits and doesn't push the strip.
/// - Emote (Y) wiggles the cursor.
///
/// When all players voted the server counts down (one game) or starts a
/// tournament (several). Going back to the lobby is asked from the phone and
/// needs the majority.
class LibraryView extends StatefulWidget {
  final PresetCatalog? presetCatalog;

  const LibraryView({super.key, this.presetCatalog});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

/// Sizes of the game strip from the last layout (used to find where a card
/// is even when it is scrolled out and not built).
class _StripGeometry {
  final double cardWidth;
  final double cardHeight;
  final double columnGap;
  final double rowGap;
  final double padding;
  final double topPadding;
  final double viewport;

  const _StripGeometry({
    required this.cardWidth,
    required this.cardHeight,
    required this.columnGap,
    required this.rowGap,
    required this.padding,
    required this.topPadding,
    required this.viewport,
  });

  double columnLeft(int column) => padding + column * (cardWidth + columnGap);

  double contentWidth(int columns) =>
      columns == 0 ? 0 : columns * cardWidth + (columns - 1) * columnGap;

  double rowCenter(int row) =>
      topPadding + row * (cardHeight + rowGap) + cardHeight / 2;
}

/// A cursor sliding in from the left edge as the library opens.
class _CursorEntry {
  final Offset to;
  final double start; // seconds since the library opened

  const _CursorEntry(this.to, this.start);
}

class _LibraryViewState extends State<LibraryView>
    with SingleTickerProviderStateMixin {
  // Cursors present when the library opens glide in from the left edge,
  // one after the other, as if the players walked in from the lobby.
  static const double _entryWindow = 0.6;
  static const double _entryDelay = 0.12;
  static const double _entryStagger = 0.07;
  static const double _entryDuration = 0.55;

  // Full stick deflection crosses ~900 px per second.
  static const double _cursorSpeed = 900;
  static const double _deadZone = 0.12;
  static const double _cursorSize = 58;
  // Cursors this close to the strip's sides push it.
  static const double _pushZone = 130;
  static const double _pushSpeed = 1100;
  static const double _sideWidth = 46;

  late final Ticker _ticker;

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _gridKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  // Everything a cursor can press (see LibraryTargets).
  final Map<String, GlobalKey> _targetKeys = {};
  final ValueNotifier<Map<String, Offset>> _cursors = ValueNotifier(const {});
  // deviceId -> target under that player's cursor.
  final ValueNotifier<Map<String, String>> _hovered = ValueNotifier(const {});
  // Signed push on the strip (negative: towards the left).
  final ValueNotifier<double> _push = ValueNotifier(0);
  double _scrollVelocity = 0;
  double _mousePush = 0;
  LibraryFilter _filter = const LibraryFilter();
  // Mouse-only details panel (players read details on their phones).
  String? _detailsGameId;
  final ValueNotifier<int> _countdownLeft = ValueNotifier(0);
  final ValueNotifier<Map<String, int>> _bopTriggers = ValueNotifier(const {});
  final ValueNotifier<Map<String, int>> _emoteTriggers = ValueNotifier(
    const {},
  );
  final Map<String, String?> _lastVotes = {};
  // D-pad: where each cursor is gliding to (a card or chip center).
  final Map<String, Offset> _hops = {};
  final Map<String, _CursorEntry> _entering = {};
  StreamSubscription<PadButtonEvent>? _buttons;
  Duration _lastTick = Duration.zero;

  List<List<GameEntry>> _columns = const [];
  int _startColumn = 0;
  _StripGeometry? _geometry;
  String? _centeredFor;

  @override
  void initState() {
    super.initState();
    _filter = _filter.copyWith(
      sort: LibraryFilter.parseSort(AppPreferences.sortOrderNotifier.value),
    );
    AppPreferences.cardStyleNotifier.addListener(_onPrefsChanged);
    AppPreferences.gridRowsNotifier.addListener(_onPrefsChanged);
    AppPreferences.sortOrderNotifier.addListener(_onPrefsChanged);
    _ticker = createTicker(_tick)..start();
    _buttons = context.read<GamepadState>().buttonEvents.listen(_onButton);
  }

  void _onPrefsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppPreferences.cardStyleNotifier.removeListener(_onPrefsChanged);
    AppPreferences.gridRowsNotifier.removeListener(_onPrefsChanged);
    AppPreferences.sortOrderNotifier.removeListener(_onPrefsChanged);
    _ticker.dispose();
    _buttons?.cancel();
    _cursors.dispose();
    _hovered.dispose();
    _push.dispose();
    _scroll.dispose();
    _countdownLeft.dispose();
    _bopTriggers.dispose();
    _emoteTriggers.dispose();
    super.dispose();
  }

  Size? get _stackSize {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.size;
  }

  SessionSnapshot get _snapshot => context.read<SessionController>().snapshot;

  /// Players whose cursor is stuck as a vote sticker or waiting while they
  /// read details: they neither move nor push.
  bool _parked(SessionPlayer player) =>
      player.vote != null || _snapshot.reading.containsKey(player.deviceId);

  void _tick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.016
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    final session = context.read<SessionController>();
    final gamepads = context.read<GamepadState>();
    final size = _stackSize;
    if (size == null) return;

    final countdown = session.snapshot.countdown;
    _countdownLeft.value = countdown == null
        ? 0
        : math.max(
            0,
            (countdown.endsAt.difference(DateTime.now()).inMilliseconds / 1000)
                .ceil(),
          );

    final players = session.snapshot.players;
    final now = elapsed.inMicroseconds / 1e6;
    final next = <String, Offset>{};
    for (var i = 0; i < players.length; i++) {
      final player = players[i];
      final id = player.deviceId;
      var position = _cursors.value[id];
      if (position == null) {
        // New cursors start spread along the middle of the strip.
        final home = Offset(
          size.width * (i + 1) / (players.length + 1),
          size.height / 2,
        );
        position = home;
        if (now < _entryWindow && !_parked(player)) {
          _entering[id] = _CursorEntry(home, now + _entryDelay + i * _entryStagger);
          position = Offset(-_cursorSize, home.dy);
        }
      }
      if (_entering[id] case final entry?) {
        // Still gliding in: input waits (the stick is usually still held
        // from walking out of the lobby).
        final t = ((now - entry.start) / _entryDuration).clamp(0.0, 1.0);
        final eased = Curves.easeOutBack.transform(t);
        next[id] = Offset(
          -_cursorSize + (entry.to.dx + _cursorSize) * eased,
          entry.to.dy,
        );
        if (t >= 1) _entering.remove(id);
        continue;
      }
      final prevVote = _lastVotes[id];
      if (player.vote != prevVote) {
        if (player.vote != null) {
          _onStamped();
        } else if (prevVote != null) {
          // The sticker peels off: the cursor comes back where the card is.
          position = _cardCenter(prevVote) ?? position;
          _triggerBop(id);
        }
        _lastVotes[id] = player.vote;
      }
      if (!_parked(player)) {
        final input = gamepads.inputListenable(id).value;
        final velocity = _stickVelocity(input.stickX, input.stickY);
        final hop = _hops[id];
        if (velocity != Offset.zero) {
          _hops.remove(id); // the stick takes over
          position += velocity * dt;
        } else if (hop != null) {
          // Quick glide to the D-pad's target.
          position = Offset.lerp(position, hop, 1 - math.exp(-dt * 20))!;
          if ((position - hop).distance < 1) {
            position = hop;
            _hops.remove(id);
          }
        }
      } else {
        _hops.remove(id);
      }
      next[id] = Offset(
        position.dx.clamp(0.0, size.width),
        position.dy.clamp(0.0, size.height),
      );
    }
    _lastVotes.removeWhere((id, _) => !next.containsKey(id));
    _entering.removeWhere((id, _) => !next.containsKey(id));
    _pushStrip([
      for (final player in players)
        if (!_parked(player) && !_entering.containsKey(player.deviceId))
          if (next[player.deviceId] case final point?) point,
    ], dt);
    // Hover is recomputed every frame: the strip can move under a still
    // cursor.
    final hovered = {
      for (final player in players)
        if (!_parked(player) && !_entering.containsKey(player.deviceId))
          if (next[player.deviceId] case final point?)
            if (_targetAt(point) case final target?) player.deviceId: target,
    };
    if (!_sameCursors(next, _cursors.value)) _cursors.value = next;
    if (!mapEquals(hovered, _hovered.value)) _hovered.value = hovered;
  }

  void _onStamped() {
    try {
      SoundEffectService.instance.playPlayerJoinPop();
    } catch (_) {}
  }

  Rect? _rectOf(GlobalKey key) {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || box == null || !box.attached || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: stackBox) & box.size;
  }

  /// Where a game's card is now (null when it is scrolled out of view).
  Offset? _cardCenter(String gameId) {
    final rect = _rectOf(_keyFor(LibraryTargets.game(gameId)));
    final grid = _rectOf(_gridKey);
    if (rect == null || grid == null || !grid.overlaps(rect)) return null;
    return rect.center;
  }

  /// Cursors or the mouse at the strip's sides push it; opposite pushes cancel out.
  /// The speed eases towards the push so it feels like shoving, not jumping.
  void _pushStrip(List<Offset> cursors, double dt) {
    final grid = _rectOf(_gridKey);
    if (grid == null || !_scroll.hasClients) return;
    if (_scroll.position.maxScrollExtent <= 0) {
      _push.value = 0;
      _scrollVelocity = 0;
      return;
    }
    final frame = Rect.fromLTRB(
      grid.left - _sideWidth,
      grid.top,
      grid.right + _sideWidth,
      grid.bottom,
    );
    final cursorForce = edgePushForce(cursors, frame, _pushZone + _sideWidth);
    final force = (cursorForce + _mousePush).clamp(-2.0, 2.0);
    _push.value = force;
    final target = force.clamp(-2.0, 2.0) * _pushSpeed;
    final blend = 1 - math.exp(-dt * 7);
    _scrollVelocity += (target - _scrollVelocity) * blend;
    if (_scrollVelocity.abs() < 1) {
      _scrollVelocity = 0;
      return;
    }
    final position = _scroll.position;
    final next = (position.pixels + _scrollVelocity * dt).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next != position.pixels) {
      _scroll.jumpTo(next);
    } else {
      _scrollVelocity = 0;
    }
  }

  void _stepScroll(bool left) {
    if (!_scroll.hasClients) return;
    final geometry = _geometry;
    final step = geometry != null
        ? (geometry.cardWidth + geometry.columnGap)
        : 260.0;
    final position = _scroll.position;
    final target = left
        ? math.max(position.minScrollExtent, _scroll.offset - step)
        : math.min(position.maxScrollExtent, _scroll.offset + step);
    _scrollVelocity = 0;
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    try {
      SoundEffectService.instance.playPlayerJoinPop();
    } catch (_) {}
  }

  GlobalKey _keyFor(String target) =>
      _targetKeys.putIfAbsent(target, GlobalKey.new);

  static int _priority(String target) {
    if (target.startsWith('filter:') ||
        target.startsWith('tag:') ||
        target.startsWith('nav:')) {
      return 3;
    }
    if (target.startsWith('game:')) return 4;
    return 99;
  }

  Offset _stickVelocity(double x, double y) {
    final magnitude = math.sqrt(x * x + y * y);
    if (magnitude < _deadZone) return Offset.zero;
    // Ease in so small tilts allow precise aiming.
    final eased = math
        .pow((magnitude - _deadZone) / (1 - _deadZone), 1.6)
        .toDouble();
    return Offset(x / magnitude, y / magnitude) * eased * _cursorSpeed;
  }

  static bool _sameCursors(Map<String, Offset> a, Map<String, Offset> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || (other - entry.value).distanceSquared > 0.01) {
        return false;
      }
    }
    return true;
  }

  /// What a cursor at [point] would press: header chips first, then games
  /// (only inside the visible strip).
  String? _targetAt(Offset point) {
    final grid = _rectOf(_gridKey);
    String? best;
    var bestPriority = 99;
    for (final entry in _targetKeys.entries) {
      final target = entry.key;
      final priority = _priority(target);
      if (priority >= bestPriority) continue;
      final rect = _rectOf(entry.value);
      if (rect == null || !rect.contains(point)) continue;
      // Cards scrolled out of the strip's viewport can't be pressed.
      if (priority == 4 && !(grid?.contains(point) ?? false)) continue;
      best = target;
      bestPriority = priority;
    }
    return best;
  }

  void _onButton(PadButtonEvent event) {
    if (!event.pressed) return;
    final session = context.read<SessionController>();
    final id = event.deviceId;
    final player = session.playerById(id);
    if (player == null || _entering.containsKey(id)) return;
    final reading = session.snapshot.reading[id];
    switch (event.button) {
      case 'A' || 'START':
        if (reading != null) {
          // Select while reading votes for the game being read.
          unawaited(session.vote(id, reading));
          unawaited(session.showDetails(id, null));
          return;
        }
        if (player.vote != null) return;
        final cursor = _cursors.value[id];
        if (cursor == null) return;
        final target = _targetAt(cursor);
        if (target != null) _press(target, id);
      case 'X':
        if (reading != null || player.vote != null) return;
        final cursor = _cursors.value[id];
        final target = cursor == null ? null : _targetAt(cursor);
        if (target != null && target.startsWith('game:')) {
          _triggerBop(id);
          unawaited(session.showDetails(id, target.substring(5)));
        }
      case 'B':
        if (reading != null) {
          unawaited(session.showDetails(id, null));
        } else if (player.vote != null) {
          unawaited(session.vote(id, null));
        }
      case 'Y':
        _triggerEmote(id);
      case 'UP' || 'DOWN' || 'LEFT' || 'RIGHT':
        if (reading != null || player.vote != null) return;
        _hop(id, event.button);
    }
  }

  /// D-pad: the cursor jumps to the nearest card or chip in that direction.
  /// With no card left on that side of the strip, it scrolls one card and
  /// then jumps.
  void _hop(String id, String direction, {bool scrolled = false}) {
    final from = _hops[id] ?? _cursors.value[id];
    if (from == null) return;
    final d = switch (direction) {
      'UP' => const Offset(0, -1),
      'DOWN' => const Offset(0, 1),
      'LEFT' => const Offset(-1, 0),
      _ => const Offset(1, 0),
    };
    final grid = _rectOf(_gridKey);
    Offset? best;
    var bestScore = double.infinity;
    for (final entry in _targetKeys.entries) {
      final rect = _rectOf(entry.value);
      if (rect == null) continue;
      final center = rect.center;
      // Cards scrolled out of the strip's viewport don't count.
      if (_priority(entry.key) == 4 && !(grid?.contains(center) ?? false)) continue;
      final v = center - from;
      final along = v.dx * d.dx + v.dy * d.dy;
      if (along <= 8) continue;
      final across = (v.dx * d.dy - v.dy * d.dx).abs();
      final score = along + across * 2;
      if (score < bestScore) {
        bestScore = score;
        best = center;
      }
    }
    if (best != null) {
      _hops[id] = best;
      return;
    }
    if (!scrolled && (direction == 'LEFT' || direction == 'RIGHT')) {
      _stepScroll(direction == 'LEFT');
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) _hop(id, direction, scrolled: true);
      });
    }
  }

  /// A cursor ([deviceId]) or the mouse (null) pressed [target].
  void _press(String target, String? deviceId) {
    final session = context.read<SessionController>();
    void pop() {
      if (deviceId != null) _triggerBop(deviceId);
      try {
        SoundEffectService.instance.playPlayerJoinPop();
      } catch (_) {}
    }

    if (target.startsWith('game:')) {
      final gameId = target.substring(5);
      if (deviceId == null) {
        unawaited(session.play(gameId));
      } else {
        unawaited(session.vote(deviceId, gameId));
      }
    } else if (target.startsWith('tag:')) {
      pop();
      setState(() => _filter = _filter.toggleTag(target.substring(4)));
    } else if (target == LibraryTargets.fitsOnly) {
      pop();
      setState(() => _filter = _filter.copyWith(fitsOnly: !_filter.fitsOnly));
    } else if (target == LibraryTargets.sort) {
      pop();
      setState(() => _filter = _filter.nextSort());
    } else if (target == LibraryTargets.clear) {
      pop();
      setState(() => _filter = LibraryFilter(sort: _filter.sort));
    } else if (target == LibraryTargets.lobby) {
      pop();
      // The host leaves right away; a player asks the others.
      unawaited(
        deviceId == null
            ? session.backToLobby()
            : session.requestLobby(deviceId),
      );
    } else if (target == LibraryTargets.freeMode) {
      pop();
      unawaited(session.enterFreeMode());
    } else if (target == LibraryTargets.panelClose) {
      _closeDetails();
    } else if (target == LibraryTargets.panelVote) {
      final gameId = _detailsGameId;
      if (gameId != null) unawaited(session.play(gameId));
    } else if (target == LibraryTargets.panelTrailer) {
      final url = session.gameById(_detailsGameId)?.trailerUrl ?? '';
      final uri = Uri.tryParse(url);
      if (uri != null && uri.hasScheme) {
        unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
      }
    }
  }

  void _closeDetails() {
    if (_detailsGameId == null) return;
    setState(() => _detailsGameId = null);
  }

  void _triggerBop(String deviceId) {
    final next = Map<String, int>.from(_bopTriggers.value);
    next[deviceId] = (next[deviceId] ?? 0) + 1;
    _bopTriggers.value = next;
  }

  void _triggerEmote(String deviceId) {
    final next = Map<String, int>.from(_emoteTriggers.value);
    next[deviceId] = (next[deviceId] ?? 0) + 1;
    _emoteTriggers.value = next;
  }

  void _openManageGames() {
    showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<SessionController>(),
        child: ManageGamesDialog(presetCatalog: widget.presetCatalog),
      ),
    );
  }

  /// Brings the start column into view whenever the shown games change.
  void _centerStrip(String signature) {
    if (_centeredFor == signature) return;
    _centeredFor = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final geometry = _geometry;
      if (!mounted || geometry == null || !_scroll.hasClients) return;
      final position = _scroll.position;
      // Four whole columns on screen, the start column second from the
      // left so there are games on both sides of it.
      final first = math.max(0, _startColumn - 1);
      final target = geometry.columnLeft(first) - 36;
      _scrollVelocity = 0;
      _scroll.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final gamepads = context.watch<GamepadState>();
    final strings = context.l10n.session;
    final snapshot = session.snapshot;
    final playerCount = snapshot.players.length;

    final prefSort = LibraryFilter.parseSort(
      AppPreferences.sortOrderNotifier.value,
    );
    if (_filter.sort != prefSort) {
      _filter = _filter.copyWith(sort: prefSort);
    }
    final rows = AppPreferences.gridRowsNotifier.value;
    final isCoverOnly = AppPreferences.cardStyleNotifier.value == 'cover_only';

    final games = _filter.apply(session.games, playerCount);
    final layout = layoutColumns(
      games,
      perColumn: rows,
      centerOut: false,
    );
    _columns = layout.columns;
    _startColumn = layout.start;
    _centerStrip(
      '${_filter.sort}|${_filter.fitsOnly}|${_filter.tags.join(',')}|'
      '${games.map((g) => g.id).join(',')}|$rows|$isCoverOnly',
    );

    final details = session.gameById(_detailsGameId);
    if (_detailsGameId != null && details == null) _detailsGameId = null;
    List<DeviceModel> devices(Iterable<String> ids) => [
      for (final id in ids)
        if (gamepads.deviceById(id) case final device?) device,
    ];
    List<DeviceModel> hoveredBy(Map<String, String> hovered, String target) =>
        devices([
          for (final entry in hovered.entries)
            if (entry.value == target) entry.key,
        ]);
    final players = devices(snapshot.players.map((p) => p.deviceId));

    return Stack(
      key: _stackKey,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: snapshot.lobbyRequest == null
                  ? const SizedBox(width: double.infinity)
                  : _LobbyRequestStrip(request: snapshot.lobbyRequest!),
            ),
            if (snapshot.lastError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _ErrorStrip(
                  text: strings.launchError(snapshot.lastError!),
                ),
              ),
            Expanded(
              child: ColoredBox(
                color: AppColors.screenBackground,
                child: session.games.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(strings.emptyLibrary, style: _titleStyle),
                            const SizedBox(height: 16),
                            JuicyButton(
                              onPressed: _openManageGames,
                              backgroundColor: AppColors.highlightColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: Text(
                                strings.addFirstGame,
                                style: _buttonStyle,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildStrip(
                        snapshot: snapshot,
                        session: session,
                        playerCount: playerCount,
                        devices: devices,
                        hoveredBy: hoveredBy,
                        details: details,
                        empty: games.isEmpty,
                        rows: rows,
                        isCoverOnly: isCoverOnly,
                      ),
              ),
            ),
            ValueListenableBuilder<Map<String, String>>(
              valueListenable: _hovered,
              builder: (context, hovered, _) => _LibraryFooter(
                players: players,
                snapshot: snapshot,
                gameName: (id) => session.gameById(id)?.name ?? '',
                keyFor: _keyFor,
                hoveredBy: (target) => hoveredBy(hovered, target),
                onPress: (target) => _press(target, null),
              ),
            ),
          ],
        ),
        if (snapshot.countdown != null)
          Positioned.fill(
            child: _CountdownOverlay(
              game: session.gameById(snapshot.countdown!.gameId),
              secondsLeft: _countdownLeft,
              onCancel: session.cancelCountdown,
            ),
          ),
        // Cursors float above everything and never take mouse events.
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<Map<String, Offset>>(
              valueListenable: _cursors,
              builder: (context, cursors, _) =>
                  ValueListenableBuilder<Map<String, int>>(
                    valueListenable: _bopTriggers,
                    builder: (context, bops, _) =>
                        ValueListenableBuilder<Map<String, int>>(
                          valueListenable: _emoteTriggers,
                          builder: (context, emotes, _) => Stack(
                            children: [
                              for (final entry in cursors.entries)
                                if (gamepads.deviceById(entry.key)
                                    case final device?)
                                  // Voted: the cursor is a sticker on the card.
                                  if (session.playerById(entry.key)?.vote ==
                                      null)
                                    Positioned(
                                      left: entry.value.dx - _cursorSize / 2,
                                      top: entry.value.dy - _cursorSize / 2,
                                      child: PlayerCursor(
                                        device: device,
                                        size: _cursorSize,
                                        bopTrigger: bops[entry.key] ?? 0,
                                        emoteTrigger: emotes[entry.key] ?? 0,
                                        reading: snapshot.reading.containsKey(
                                          entry.key,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                  ),
            ),
          ),
        ),
      ],
    );
  }

  /// The framed strip: push zones on both sides (when content overflows),
  /// cards scrolling sideways, and faces pinned at the edge for votes on
  /// cards that are out of view.
  Widget _buildStrip({
    required SessionSnapshot snapshot,
    required SessionController session,
    required int playerCount,
    required List<DeviceModel> Function(Iterable<String>) devices,
    required List<DeviceModel> Function(Map<String, String>, String) hoveredBy,
    required GameEntry? details,
    required bool empty,
    required int rows,
    required bool isCoverOnly,
  }) {
    final strings = context.l10n.session;
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const columnGap = 26.0;
          const rowGap = 22.0;
          const topPadding = 22.0;
          final cardHeight = math.max(
            120.0,
            (constraints.maxHeight - topPadding * 2 - rowGap * (rows - 1)) / rows,
          );
          const sidePadding = 36.0;
          final cardWidth = isCoverOnly
              ? math.max(140.0, cardHeight * (2.0 / 3.0))
              : math.max(
                  220.0,
                  (constraints.maxWidth - sidePadding * 2 - columnGap * 3) / 4,
                );
          final content =
              _columns.length * cardWidth +
              math.max(0, _columns.length - 1) * columnGap;
          // Only show side push arrows if games overflow the screen.
          final bool needsScroll =
              content + sidePadding * 2 > constraints.maxWidth;
          final double effectiveSideWidth = needsScroll ? _sideWidth : 0.0;
          final viewport = constraints.maxWidth - effectiveSideWidth * 2;
          final padding = math.max(
            sidePadding,
            (viewport - content) / 2,
          );
          final geometry = _StripGeometry(
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            columnGap: columnGap,
            rowGap: rowGap,
            padding: padding,
            topPadding: topPadding,
            viewport: viewport,
          );
          _geometry = geometry;

          if (empty) {
            return Center(
              child: Text(strings.noGamesMatch, style: _bodyStyle),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (needsScroll)
                _PushSide(
                  push: _push,
                  left: true,
                  width: _sideWidth,
                  onTap: () => _stepScroll(true),
                  onPushChange: (p) => _mousePush = p,
                ),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ValueListenableBuilder<Map<String, String>>(
                        valueListenable: _hovered,
                        builder: (context, hovered, _) => ListView.separated(
                          key: _gridKey,
                          controller: _scroll,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: padding,
                            vertical: topPadding,
                          ),
                          itemCount: _columns.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: columnGap),
                          itemBuilder: (context, column) => Column(
                            children: [
                              for (final (row, game)
                                  in _columns[column].indexed) ...[
                                if (row > 0) const SizedBox(height: rowGap),
                                LibraryGameCard(
                                  key: _keyFor(LibraryTargets.game(game.id)),
                                  game: game,
                                  playerCount: playerCount,
                                  width: cardWidth,
                                  height: cardHeight,
                                  coverOnly: isCoverOnly,
                                  voters: devices(session.votersFor(game.id)),
                                  hoveredBy: hoveredBy(
                                    hovered,
                                    LibraryTargets.game(game.id),
                                  ),
                                  isCountdownTarget:
                                      snapshot.countdown?.gameId == game.id,
                                  onTap: () => _press(
                                    LibraryTargets.game(game.id),
                                    null,
                                  ),
                                  onSecondaryTap: () =>
                                      setState(() => _detailsGameId = game.id),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Votes on cards scrolled out of view show at the edge.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _scroll,
                          builder: (context, _) =>
                              _buildOffscreenVotes(snapshot, geometry),
                        ),
                      ),
                    ),
                    // Mouse-only details (right click on a card).
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) =>
                            SlideTransition(
                              position: Tween(
                                begin: const Offset(1.1, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                        child: details == null
                            ? const SizedBox.shrink()
                            : SizedBox(
                                key: ValueKey(details.id),
                                width: 420,
                                child: GameDetailsPanel(
                                  game: details,
                                  playerCount: playerCount,
                                  openedBy: null,
                                  voters: devices(
                                    session.votersFor(details.id),
                                  ),
                                  keyFor: (_) => GlobalKey(),
                                  hoveredBy: (_) => const [],
                                  onPress: (target) => _press(target, null),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              if (needsScroll)
                _PushSide(
                  push: _push,
                  left: false,
                  width: _sideWidth,
                  onTap: () => _stepScroll(false),
                  onPushChange: (p) => _mousePush = p,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOffscreenVotes(SessionSnapshot snapshot, _StripGeometry g) {
    if (!_scroll.hasClients) return const SizedBox.shrink();
    final gamepads = context.read<GamepadState>();
    final offset = _scroll.offset;
    final left = <(DeviceModel, double)>[];
    final right = <(DeviceModel, double)>[];
    for (final player in snapshot.players) {
      final vote = player.vote;
      if (vote == null) continue;
      final device = gamepads.deviceById(player.deviceId);
      if (device == null) continue;
      for (final (column, games) in _columns.indexed) {
        final row = games.indexWhere((game) => game.id == vote);
        if (row < 0) continue;
        final x = g.columnLeft(column) - offset;
        if (x + g.cardWidth * 0.5 < 0) {
          left.add((device, g.rowCenter(row)));
        } else if (x + g.cardWidth * 0.5 > g.viewport) {
          right.add((device, g.rowCenter(row)));
        }
        break;
      }
    }
    Iterable<Widget> pins(
      List<(DeviceModel, double)> faces,
      bool onLeft,
    ) sync* {
      final counts = <int, int>{};
      for (final (device, y) in faces) {
        // Several faces at the same height fan out a little.
        final slot = counts.update(y.round(), (c) => c + 1, ifAbsent: () => 0);
        yield Positioned(
          key: ValueKey('pin_${device.id}'),
          left: onLeft ? 6.0 + slot * 18 : null,
          right: onLeft ? null : 6.0 + slot * 18,
          top: y - 26,
          child: _EdgePin(device: device, pointsLeft: onLeft),
        );
      }
    }

    return Stack(children: [...pins(left, true), ...pins(right, false)]);
  }
}

/// A side of the strip: lights up and scrolls while cursors or the mouse push that way.
class _PushSide extends StatefulWidget {
  final ValueListenable<double> push;
  final bool left;
  final double width;
  final VoidCallback? onTap;
  final ValueChanged<double>? onPushChange;

  const _PushSide({
    required this.push,
    required this.left,
    required this.width,
    this.onTap,
    this.onPushChange,
  });

  @override
  State<_PushSide> createState() => _PushSideState();
}

class _PushSideState extends State<_PushSide> {
  bool _hovered = false;
  bool _pressed = false;
  DateTime? _downTime;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.push,
      builder: (context, force, _) {
        final amount = (widget.left ? -force : force).clamp(0.0, 1.0);
        final effectiveAmount = math.max(
          amount,
          _pressed ? 1.0 : (_hovered ? 0.45 : 0.0),
        );
        final iconScale = _pressed ? 0.9 : (_hovered ? 1.25 : 1.0);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            setState(() => _hovered = true);
            try {
              SoundEffectService.instance.playHover();
            } catch (_) {}
          },
          onExit: (_) {
            setState(() {
              _hovered = false;
              if (_pressed) {
                _pressed = false;
                widget.onPushChange?.call(0.0);
              }
            });
          },
          child: Listener(
            onPointerDown: (event) {
              if (event.buttons != kPrimaryMouseButton) return;
              _downTime = DateTime.now();
              setState(() => _pressed = true);
              widget.onPushChange?.call(widget.left ? -1.0 : 1.0);
            },
            onPointerUp: (_) {
              if (_pressed) {
                setState(() => _pressed = false);
                widget.onPushChange?.call(0.0);
              }
            },
            onPointerCancel: (_) {
              if (_pressed) {
                setState(() => _pressed = false);
                widget.onPushChange?.call(0.0);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final down = _downTime;
                if (down == null ||
                    DateTime.now().difference(down) <
                        const Duration(milliseconds: 350)) {
                  widget.onTap?.call();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: widget.width,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    AppColors.screenBackground,
                    AppColors.highlightColor,
                    effectiveAmount,
                  ),
                ),
                child: Center(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 120),
                    scale: iconScale,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 120),
                      offset: Offset(
                        (widget.left ? -0.22 : 0.22) * effectiveAmount,
                        0,
                      ),
                      child: Icon(
                        widget.left
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        size: 34,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A vote on a card out of view: the face at the strip's edge, pointing to
/// where the card is.
class _EdgePin extends StatelessWidget {
  final DeviceModel device;
  final bool pointsLeft;

  const _EdgePin({required this.device, required this.pointsLeft});

  @override
  Widget build(BuildContext context) {
    final arrow = Icon(
      pointsLeft ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      size: 26,
      color: AppColors.textPrimary,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.lightColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.textPrimary, width: 3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pointsLeft) arrow,
            FaceSticker(face: device.face, size: 40),
            if (!pointsLeft) arrow,
          ],
        ),
      ),
    );
  }
}

/// "Ana wants to go back to the lobby — 2/3" while the others decide.
class _LobbyRequestStrip extends StatelessWidget {
  final LobbyRequest request;

  const _LobbyRequestStrip({required this.request});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.highlightColor,
        border: const Border(
          bottom: BorderSide(color: AppColors.textPrimary, width: 3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.how_to_vote_rounded, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Text(
            strings.lobbyRequest(request.fromName, request.yes, request.needed),
            style: _buttonStyle.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// One chip per player: what each one is doing, plus back to lobby in the left corner.
class _LibraryFooter extends StatelessWidget {
  final List<DeviceModel> players;
  final SessionSnapshot snapshot;
  final String Function(String gameId) gameName;
  final GlobalKey Function(String target) keyFor;
  final List<DeviceModel> Function(String target) hoveredBy;
  final ValueChanged<String> onPress;

  const _LibraryFooter({
    required this.players,
    required this.snapshot,
    required this.gameName,
    required this.keyFor,
    required this.hoveredBy,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final voted = snapshot.players.where((p) => p.vote != null).length;
    final lobbyTarget = LibraryTargets.lobby;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.lightColor,
        border: Border(
          top: BorderSide(color: AppColors.textPrimary, width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          LibraryChip(
            key: keyFor(lobbyTarget),
            label: strings.backToLobby,
            icon: Icons.arrow_back_rounded,
            selected: false,
            backgroundColor: AppColors.screenBackground,
            hoveredBy: hoveredBy(lobbyTarget),
            onTap: () => onPress(lobbyTarget),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final device in players)
                  _PlayerStatusChip(
                    device: device,
                    status: _status(strings, device.id),
                    done: snapshot.players.any(
                      (p) => p.deviceId == device.id && p.vote != null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            strings.votedCount(voted, snapshot.players.length),
            style: _captionStyle.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _status(SessionStrings strings, String deviceId) {
    final player = snapshot.players
        .where((p) => p.deviceId == deviceId)
        .firstOrNull;
    if (snapshot.lobbyRequest?.fromDeviceId == deviceId) {
      return strings.statusWantsLobby;
    }
    if (player?.vote case final vote?) return gameName(vote);
    if (snapshot.reading[deviceId] case final reading?) {
      return strings.statusReading(gameName(reading));
    }
    return strings.statusChoosing;
  }
}

class _PlayerStatusChip extends StatelessWidget {
  final DeviceModel device;
  final String status;
  final bool done;

  const _PlayerStatusChip({
    required this.device,
    required this.status,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: done ? AppColors.highlightColor : AppColors.screenBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textPrimary, width: 2.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaceSticker(face: device.face, size: 30),
          const SizedBox(width: 8),
          Text(device.name, style: _buttonStyle),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _captionStyle.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownOverlay extends StatefulWidget {
  final GameEntry? game;
  final ValueListenable<int> secondsLeft;
  final VoidCallback onCancel;

  const _CountdownOverlay({
    required this.game,
    required this.secondsLeft,
    required this.onCancel,
  });

  @override
  State<_CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<_CountdownOverlay> {
  int _lastSeconds = -1;
  int _burstTrigger = 0;

  @override
  void initState() {
    super.initState();
    widget.secondsLeft.addListener(_onSecondsChanged);
    _onSecondsChanged();
  }

  @override
  void didUpdateWidget(covariant _CountdownOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.secondsLeft != widget.secondsLeft) {
      oldWidget.secondsLeft.removeListener(_onSecondsChanged);
      widget.secondsLeft.addListener(_onSecondsChanged);
    }
  }

  @override
  void dispose() {
    widget.secondsLeft.removeListener(_onSecondsChanged);
    super.dispose();
  }

  void _onSecondsChanged() {
    final s = widget.secondsLeft.value;
    if (s != _lastSeconds) {
      _lastSeconds = s;
      _burstTrigger++;
      if (s > 0) {
        try {
          SoundEffectService.instance.playCountdownTick();
        } catch (_) {}
      } else if (s == 0) {
        try {
          SoundEffectService.instance.playCountdownGo();
        } catch (_) {}
      }
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final seconds = widget.secondsLeft.value;

    return Container(
      color: AppColors.screenBackground.withValues(alpha: 0.78),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.lightColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.textPrimary, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.startingIn(widget.game?.name ?? ''),
              style: _titleStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ComicBopBurst(
              trigger: _burstTrigger,
              burstRadius: 78,
              rayCount: 12,
              rayWidth: 4.5,
              burstColor: AppColors.highlightColor,
              showDots: true,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(seconds),
                tween: Tween(begin: 1.7, end: 1.0),
                duration: const Duration(milliseconds: 380),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: AppColors.highlightColor.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.textPrimary, width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    seconds > 0 ? '$seconds' : '!',
                    style: const TextStyle(
                      fontFamily: 'momo',
                      fontSize: 82,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            JuicyButton(
              onPressed: widget.onCancel,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: Text(strings.cancel, style: _buttonStyle),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  final String text;

  const _ErrorStrip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textPrimary, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: _bodyStyle)),
        ],
      ),
    );
  }
}

const TextStyle _titleStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 24,
  color: AppColors.textPrimary,
);

const TextStyle _bodyStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 14,
  color: AppColors.textPrimary,
);

const TextStyle _buttonStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 14,
  color: AppColors.textPrimary,
);

final TextStyle _captionStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 12,
  color: AppColors.textPrimary.withValues(alpha: 0.65),
);
