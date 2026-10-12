import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/session_models.dart';
import '../../services/host_api_service.dart';
import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/juicy_widgets.dart';
import '../../widgets/player_face_indicator.dart';
import '../home_page/gamepad_state.dart';
import 'manage_games_dialog.dart';

/// Game library: every player steers a cursor with their own face using the
/// left stick, A votes for the game under it, B removes the vote. When all
/// players voted the server counts down and starts the most voted game.
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
  static const double _cursorSize = 46;

  late final Ticker _ticker;
  final GlobalKey _stackKey = GlobalKey();
  final Map<String, GlobalKey> _cardKeys = {};
  final ValueNotifier<Map<String, Offset>> _cursors = ValueNotifier(const {});
  final ValueNotifier<Map<String, String>> _hoveredGame = ValueNotifier(
    const {},
  );
  final ValueNotifier<int> _countdownLeft = ValueNotifier(0);
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
    _hoveredGame.dispose();
    _countdownLeft.dispose();
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
    if (!_sameCursors(next, _cursors.value)) {
      _cursors.value = next;
      _hoveredGame.value = {
        for (final entry in next.entries)
          if (_gameAt(entry.value) case final gameId?) entry.key: gameId,
      };
    }
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

  String? _gameAt(Offset point) {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return null;
    for (final entry in _cardKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final topLeft = box.localToGlobal(Offset.zero, ancestor: stackBox);
      if ((topLeft & box.size).contains(point)) return entry.key;
    }
    return null;
  }

  void _onButton(PadButtonEvent event) {
    if (!event.pressed || event.button != 'A') return;
    final cursor = _cursors.value[event.deviceId];
    if (cursor == null) return;
    final gameId = _gameAt(cursor);
    if (gameId != null) {
      unawaited(context.read<SessionController>().vote(event.deviceId, gameId));
    }
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

    final games = [...session.games]
      ..sort((a, b) {
        final fitA = a.fits(playerCount) ? 0 : 1;
        final fitB = b.fits(playerCount) ? 0 : 1;
        if (fitA != fitB) return fitA - fitB;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    _cardKeys.removeWhere((id, _) => games.every((g) => g.id != id));

    return Stack(
      key: _stackKey,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LibraryHeader(onManageGames: _openManageGames),
            if (snapshot.lastError != null) ...[
              const SizedBox(height: 8),
              _ErrorStrip(text: strings.launchError(snapshot.lastError!)),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: games.isEmpty
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
                  : SingleChildScrollView(
                      child: ValueListenableBuilder<Map<String, String>>(
                        valueListenable: _hoveredGame,
                        builder: (context, hovered, _) => Wrap(
                          spacing: 18,
                          runSpacing: 18,
                          children: [
                            for (final game in games)
                              _GameCard(
                                key: _cardKeys.putIfAbsent(
                                  game.id,
                                  GlobalKey.new,
                                ),
                                game: game,
                                fits: game.fits(playerCount),
                                playerCount: playerCount,
                                voters: [
                                  for (final id in session.votersFor(game.id))
                                    if (gamepads.deviceById(id)
                                        case final device?)
                                      device,
                                ],
                                hoveredBy: [
                                  for (final entry in hovered.entries)
                                    if (entry.value == game.id)
                                      if (gamepads.deviceById(entry.key)
                                          case final device?)
                                        device,
                                ],
                                isCountdownTarget:
                                    snapshot.countdown?.gameId == game.id,
                                onTap: () => session.play(game.id),
                              ),
                          ],
                        ),
                      ),
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
              builder: (context, cursors, _) => Stack(
                children: [
                  for (final entry in cursors.entries)
                    if (gamepads.deviceById(entry.key) case final device?)
                      Positioned(
                        left: entry.value.dx - _cursorSize / 2,
                        top: entry.value.dy - _cursorSize / 2,
                        child: _PlayerCursor(device: device, size: _cursorSize),
                      ),
                ],
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

  const _LibraryHeader({required this.onManageGames});

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

class _GameCard extends StatelessWidget {
  static const double width = 190;
  static const double coverHeight = 200;
  static const double borderWidth = 4;
  static const double radius = 18;

  final GameEntry game;
  final bool fits;
  final int playerCount;
  final List<DeviceModel> voters;
  final List<DeviceModel> hoveredBy;
  final bool isCountdownTarget;
  final VoidCallback onTap;

  const _GameCard({
    super.key,
    required this.game,
    required this.fits,
    required this.playerCount,
    required this.voters,
    required this.hoveredBy,
    required this.isCountdownTarget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final highlighted = hoveredBy.isNotEmpty || isCountdownTarget;
    final borderColor = isCountdownTarget
        ? AppColors.highlightColor
        : (hoveredBy.isNotEmpty
              ? hoveredBy.first.color
              : AppColors.textPrimary);

    return Tooltip(
      message: strings.clickToPlay,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedScale(
            scale: highlighted ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Opacity(
              opacity: fits ? 1 : 0.45,
              // Same border thickness on every side, like the slot cards:
              // the content sits inside the border instead of painting over
              // it, and no offset shadow thickens the bottom/right edges.
              child: Container(
                width: width,
                padding: const EdgeInsets.all(borderWidth),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius - borderWidth),
                  child: ColoredBox(
                    color: AppColors.lightColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: coverHeight,
                          child: _Cover(game: game),
                        ),
                        Container(height: borderWidth, color: borderColor),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _cardTitleStyle,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                fits
                                    ? strings.playersRange(
                                        game.minPlayers,
                                        game.maxPlayers,
                                      )
                                    : strings.doesNotFit(playerCount),
                                style: _captionStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 30,
                                child: Row(
                                  children: [
                                    for (final voter in voters.take(6))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 4,
                                        ),
                                        child: TweenAnimationBuilder<double>(
                                          key: ValueKey('vote_${voter.id}'),
                                          tween: Tween(begin: 0.2, end: 1),
                                          duration: const Duration(
                                            milliseconds: 420,
                                          ),
                                          curve: Curves.elasticOut,
                                          builder: (context, scale, child) =>
                                              Transform.scale(
                                                scale: scale,
                                                child: child,
                                              ),
                                          child: PlayerFaceIndicator(
                                            face: voter.face,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final GameEntry game;

  const _Cover({required this.game});

  @override
  Widget build(BuildContext context) {
    if (game.coverPath.isNotEmpty && File(game.coverPath).existsSync()) {
      return Image.file(File(game.coverPath), fit: BoxFit.cover);
    }
    // Placeholder: a color picked from the name, with its initials.
    final hue = (game.name.codeUnits.fold<int>(0, (a, b) => a + b) * 37) % 360;
    final words = game.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    final initials = words.take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      color: HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.72).toColor(),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontFamily: 'momo',
          fontSize: 56,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _PlayerCursor extends StatelessWidget {
  final DeviceModel device;
  final double size;

  const _PlayerCursor({required this.device, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Pointer tip at the cursor's center (top-left of the face).
          Positioned(
            left: size / 2 - 7,
            top: size / 2 - 7,
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: Icon(
                Icons.navigation_rounded,
                size: 18,
                color: device.color,
              ),
            ),
          ),
          Positioned(
            left: size / 2,
            top: size / 2,
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
              child: PlayerFaceIndicator(face: device.face, size: size * 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  final GameEntry? game;
  final ValueListenable<int> secondsLeft;
  final VoidCallback onCancel;

  const _CountdownOverlay({
    required this.game,
    required this.secondsLeft,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    return Container(
      color: AppColors.screenBackground.withValues(alpha: 0.75),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.lightColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.textPrimary, width: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.startingIn(game?.name ?? ''),
              style: _titleStyle,
              textAlign: TextAlign.center,
            ),
            ValueListenableBuilder<int>(
              valueListenable: secondsLeft,
              builder: (context, seconds, _) => TweenAnimationBuilder<double>(
                key: ValueKey(seconds),
                tween: Tween(begin: 1.6, end: 1),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Text(
                  '$seconds',
                  style: const TextStyle(
                    fontFamily: 'momo',
                    fontSize: 96,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            JuicyButton(
              onPressed: onCancel,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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

const TextStyle _cardTitleStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 16,
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
