import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/session_models.dart';
import '../../services/host_api_service.dart';
import '../../services/session_controller.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../widgets/juicy_widgets.dart';
import '../../widgets/comic_burst.dart';
import '../../widgets/player_face_indicator.dart';
import '../../services/sound_effect_service.dart';
import '../home_page/gamepad_state.dart';
import 'library_browser.dart';
import 'manage_games_dialog.dart';

/// Game library: every player steers a cursor with their own face using the
/// left stick. Select (A) presses what is under it: a game votes for it, the
/// "i" opens its details, chips filter/sort. Back (B) closes the details the
/// player opened, otherwise removes their vote. When all players voted the
/// server counts down (one game) or starts a tournament (several).
class LibraryView extends StatefulWidget {
  final PresetCatalog? presetCatalog;

  const LibraryView({super.key, this.presetCatalog});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView>
    with SingleTickerProviderStateMixin {
  // Full stick deflection crosses ~900 px per second.
  static const double _cursorSpeed = 900;
  static const double _deadZone = 0.12;
  static const double _cursorSize = 58;

  late final Ticker _ticker;
  // Cursors near the top/bottom of the grid scroll it.
  static const double _edgeZone = 70;
  static const double _edgeScrollSpeed = 700;

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _gridKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  // Everything a cursor can press (see LibraryTargets).
  final Map<String, GlobalKey> _targetKeys = {};
  final ValueNotifier<Map<String, Offset>> _cursors = ValueNotifier(const {});
  // deviceId -> target under that player's cursor.
  final ValueNotifier<Map<String, String>> _hovered = ValueNotifier(const {});
  LibraryFilter _filter = const LibraryFilter();
  String? _detailsGameId;
  String? _detailsOwner;
  final ValueNotifier<int> _countdownLeft = ValueNotifier(0);
  final ValueNotifier<Map<String, int>> _bopTriggers = ValueNotifier(const {});
  final Map<String, String?> _lastVotes = {};
  StreamSubscription<PadButtonEvent>? _buttons;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _buttons = context.read<GamepadState>().buttonEvents.listen(_onButton);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _buttons?.cancel();
    _cursors.dispose();
    _hovered.dispose();
    _scroll.dispose();
    _countdownLeft.dispose();
    _bopTriggers.dispose();
    super.dispose();
  }

  Size? get _stackSize =>
      (_stackKey.currentContext?.findRenderObject() as RenderBox?)?.size;

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
    for (final player in players) {
      final prevVote = _lastVotes[player.deviceId];
      if (player.vote != null && player.vote != prevVote) {
        _triggerBop(player.deviceId);
      }
      _lastVotes[player.deviceId] = player.vote;
    }

    final next = <String, Offset>{};
    for (var i = 0; i < players.length; i++) {
      final id = players[i].deviceId;
      var position =
          _cursors.value[id] ??
          // New cursors start spread along the bottom.
          Offset(size.width * (i + 1) / (players.length + 1), size.height - 80);
      final input = gamepads.inputListenable(id).value;
      position += _stickVelocity(input.stickX, input.stickY) * dt;
      next[id] = Offset(
        position.dx.clamp(0.0, size.width),
        position.dy.clamp(0.0, size.height),
      );
    }
    _edgeScroll(next.values, dt);
    // Hover is recomputed every frame: the grid can scroll under a still
    // cursor.
    final hovered = {
      for (final entry in next.entries)
        if (_targetAt(entry.value) case final target?) entry.key: target,
    };
    if (!_sameCursors(next, _cursors.value)) _cursors.value = next;
    if (!mapEquals(hovered, _hovered.value)) _hovered.value = hovered;
  }

  Rect? _rectOf(GlobalKey key) {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || box == null || !box.attached || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: stackBox) & box.size;
  }

  void _edgeScroll(Iterable<Offset> cursors, double dt) {
    final grid = _rectOf(_gridKey);
    if (grid == null || !_scroll.hasClients) return;
    var speed = 0.0;
    for (final c in cursors) {
      if (c.dx < grid.left || c.dx > grid.right) continue;
      if (_detailsGameId != null &&
          (_rectOf(_keyFor(LibraryTargets.panel))?.contains(c) ?? false)) {
        continue;
      }
      if (c.dy > grid.bottom - _edgeZone && c.dy <= grid.bottom + 4) {
        speed += (c.dy - (grid.bottom - _edgeZone)) / _edgeZone;
      } else if (c.dy < grid.top + _edgeZone && c.dy >= grid.top - 4) {
        speed -= ((grid.top + _edgeZone) - c.dy) / _edgeZone;
      }
    }
    if (speed == 0) return;
    final position = _scroll.position;
    final target =
        (position.pixels + speed.clamp(-1.5, 1.5) * _edgeScrollSpeed * dt)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target != position.pixels) _scroll.jumpTo(target);
  }

  GlobalKey _keyFor(String target) =>
      _targetKeys.putIfAbsent(target, GlobalKey.new);

  static int _priority(String target) {
    if (target.startsWith('panel:')) return 0;
    if (target == LibraryTargets.panel) return 1;
    if (target.startsWith('info:')) return 2;
    if (target.startsWith('filter:') || target.startsWith('tag:')) return 3;
    return 4;
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
      if (other == null || (other - entry.value).distanceSquared > 0.01)
        return false;
    }
    return true;
  }

  /// What a cursor at [point] would press: panel buttons first, then the
  /// panel itself (it covers the grid), "i" buttons, chips and games.
  String? _targetAt(Offset point) {
    final grid = _rectOf(_gridKey);
    String? best;
    var bestPriority = 99;
    for (final entry in _targetKeys.entries) {
      final target = entry.key;
      final priority = _priority(target);
      if (priority >= bestPriority) continue;
      if (target.startsWith('panel') && _detailsGameId == null) continue;
      final rect = _rectOf(entry.value);
      if (rect == null || !rect.contains(point)) continue;
      // Cards scrolled out of the grid's viewport can't be pressed.
      if (priority >= 2 && priority != 3 && !(grid?.contains(point) ?? false)) {
        continue;
      }
      best = target;
      bestPriority = priority;
    }
    return best;
  }

  void _onButton(PadButtonEvent event) {
    if (!event.pressed) return;
    if (event.button == 'A' || event.button == 'START') {
      final cursor = _cursors.value[event.deviceId];
      if (cursor == null) return;
      final target = _targetAt(cursor);
      if (target != null) _press(target, event.deviceId);
    } else if (event.button == 'B') {
      _back(event.deviceId);
    }
  }

  /// Back: closes the details this player opened (or the cursor is on),
  /// otherwise removes their vote; with no votes at all, leaves the library.
  void _back(String deviceId) {
    final session = context.read<SessionController>();
    final onPanel =
        _hovered.value[deviceId]?.startsWith(LibraryTargets.panel) ?? false;
    if (_detailsGameId != null && (_detailsOwner == deviceId || onPanel)) {
      _closeDetails();
      return;
    }
    final players = session.snapshot.players;
    final mine = players.where((p) => p.deviceId == deviceId).firstOrNull;
    if (mine?.vote != null) {
      unawaited(session.vote(deviceId, null));
    } else if (players.every((p) => p.vote == null)) {
      unawaited(session.backToLobby());
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
        pop();
        unawaited(session.vote(deviceId, gameId));
      }
    } else if (target.startsWith('info:')) {
      pop();
      setState(() {
        _detailsGameId = target.substring(5);
        _detailsOwner = deviceId;
      });
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
    } else if (target == LibraryTargets.panelClose) {
      _closeDetails();
    } else if (target == LibraryTargets.panelVote) {
      final gameId = _detailsGameId;
      if (gameId == null) return;
      pop();
      if (deviceId == null) {
        unawaited(session.play(gameId));
      } else {
        unawaited(session.vote(deviceId, gameId));
      }
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
    setState(() {
      _detailsGameId = null;
      _detailsOwner = null;
    });
  }

  void _triggerBop(String deviceId) {
    final next = Map<String, int>.from(_bopTriggers.value);
    next[deviceId] = (next[deviceId] ?? 0) + 1;
    _bopTriggers.value = next;
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

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final gamepads = context.watch<GamepadState>();
    final strings = context.l10n.session;
    final snapshot = session.snapshot;
    final playerCount = snapshot.players.length;

    final tags = LibraryFilter.topTags(session.games);
    // Tags that disappeared from the library can't stay selected.
    if (_filter.tags.any((t) => !tags.containsKey(t))) {
      _filter = _filter.copyWith(
        tags: _filter.tags.where(tags.containsKey).toSet(),
      );
    }
    final games = _filter.apply(session.games, playerCount);
    final details = session.gameById(_detailsGameId);
    if (_detailsGameId != null && details == null) {
      _detailsGameId = null;
      _detailsOwner = null;
    }
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
            _LibraryHeader(onManageGames: _openManageGames, players: players),
            if (snapshot.lastError != null) ...[
              const SizedBox(height: 8),
              _ErrorStrip(text: strings.launchError(snapshot.lastError!)),
            ],
            const SizedBox(height: 12),
            if (session.games.isNotEmpty)
              ValueListenableBuilder<Map<String, String>>(
                valueListenable: _hovered,
                builder: (context, hovered, _) => LibraryFilterBar(
                  filter: _filter,
                  tags: tags,
                  playerCount: playerCount,
                  keyFor: _keyFor,
                  hoveredBy: (target) => hoveredBy(hovered, target),
                  onPress: (target) => _press(target, null),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
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
                        : games.isEmpty
                        ? Center(
                            child: Text(
                              strings.noGamesMatch,
                              style: _bodyStyle,
                            ),
                          )
                        : SingleChildScrollView(
                            key: _gridKey,
                            controller: _scroll,
                            padding: const EdgeInsets.all(8),
                            child: ValueListenableBuilder<Map<String, String>>(
                              valueListenable: _hovered,
                              builder: (context, hovered, _) => Wrap(
                                spacing: 18,
                                runSpacing: 18,
                                children: [
                                  for (final game in games)
                                    LibraryGameCard(
                                      key: _keyFor(
                                        LibraryTargets.game(game.id),
                                      ),
                                      infoKey: _keyFor(
                                        LibraryTargets.info(game.id),
                                      ),
                                      game: game,
                                      playerCount: playerCount,
                                      voters: devices(
                                        session.votersFor(game.id),
                                      ),
                                      hoveredBy: hoveredBy(
                                        hovered,
                                        LibraryTargets.game(game.id),
                                      ),
                                      infoHoveredBy: hoveredBy(
                                        hovered,
                                        LibraryTargets.info(game.id),
                                      ),
                                      isCountdownTarget:
                                          snapshot.countdown?.gameId == game.id,
                                      onTap: () => _press(
                                        LibraryTargets.game(game.id),
                                        null,
                                      ),
                                      onInfo: () => _press(
                                        LibraryTargets.info(game.id),
                                        null,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  // Details slide in from the right, over the grid.
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => SlideTransition(
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
                              child:
                                  ValueListenableBuilder<Map<String, String>>(
                                    valueListenable: _hovered,
                                    builder: (context, hovered, _) =>
                                        GameDetailsPanel(
                                          game: details,
                                          playerCount: playerCount,
                                          openedBy: _detailsOwner == null
                                              ? null
                                              : gamepads.deviceById(
                                                  _detailsOwner!,
                                                ),
                                          voters: devices(
                                            session.votersFor(details.id),
                                          ),
                                          keyFor: _keyFor,
                                          hoveredBy: (target) =>
                                              hoveredBy(hovered, target),
                                          onPress: (target) =>
                                              _press(target, null),
                                        ),
                                  ),
                            ),
                    ),
                  ),
                ],
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
                    builder: (context, bops, _) => Stack(
                      children: [
                        for (final entry in cursors.entries)
                          if (gamepads.deviceById(entry.key) case final device?)
                            Positioned(
                              left: entry.value.dx - _cursorSize / 2,
                              top: entry.value.dy - _cursorSize / 2,
                              child: PlayerCursor(
                                device: device,
                                size: _cursorSize,
                                bopTrigger: bops[entry.key] ?? 0,
                              ),
                            ),
                      ],
                    ),
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  final VoidCallback onManageGames;
  final List<DeviceModel> players;

  const _LibraryHeader({required this.onManageGames, required this.players});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final session = context.read<SessionController>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        JuicyButton(
          onPressed: session.backToLobby,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(strings.backToLobby, style: _buttonStyle),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.libraryTitle, style: _titleStyle),
              Text(
                strings.libraryHint,
                style: _captionStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        PlayerCountBadge(players: players),
        const SizedBox(width: 12),
        JuicyButton(
          onPressed: onManageGames,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.edit_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(strings.manageGames, style: _buttonStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class PlayerCursor extends StatelessWidget {
  final DeviceModel device;
  final double size;
  final int bopTrigger;

  const PlayerCursor({
    super.key,
    required this.device,
    required this.size,
    this.bopTrigger = 0,
  });

  @override
  Widget build(BuildContext context) {
    final gamepads = context.read<GamepadState>();

    return ValueListenableBuilder<DeviceInputState>(
      valueListenable: gamepads.inputListenable(device.id),
      builder: (context, input, _) {
        final stickX = -input.stickX;
        final stickY = -input.stickY;
        final isCentered = stickX == 0.0 && stickY == 0.0;
        final isPressed = input.buttonPressed;

        // Movement tilt leaning subtly into the direction of stick motion
        final tiltAngle = stickX * 0.12;

        // Mascot face lag and displacement inside the circular badge
        final maxDisplacement = size * 0.15;
        final targetTx = stickX * maxDisplacement;
        final targetTy = stickY * maxDisplacement;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Pointer tip at the cursor's center (top-left of the face).
              Positioned(
                left: size / 2 - 10,
                top: size / 2 - 10,
                child: Transform.rotate(
                  angle: -math.pi / 4,
                  child: Icon(
                    Icons.navigation_rounded,
                    size: size * 0.38,
                    color: device.color,
                  ),
                ),
              ),
              Positioned(
                left: size / 2,
                top: size / 2,
                child: ComicBopBurst(
                  trigger: bopTrigger,
                  burstColor: device.color,
                  burstRadius: size * 0.45,
                  child: TweenAnimationBuilder<Offset>(
                    tween: Tween<Offset>(
                      begin: Offset(targetTx, targetTy),
                      end: Offset(targetTx, targetTy),
                    ),
                    duration: isCentered
                        ? const Duration(milliseconds: 320)
                        : const Duration(milliseconds: 80),
                    curve: isCentered ? Curves.elasticOut : Curves.easeOutQuad,
                    builder: (context, stickOffset, child) {
                      return Transform.rotate(
                        angle: tiltAngle,
                        alignment: Alignment.center,
                        child: Transform.scale(
                          scale: isPressed ? 0.92 : 1.0,
                          alignment: Alignment.center,
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(2, 3),
                                ),
                              ],
                            ),
                            child: PlayerFaceIndicator(
                              face: device.face,
                              size: size * 0.8,
                              faceTranslateX: stickOffset.dx,
                              faceTranslateY: stickOffset.dy,
                              pressed: isPressed,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
