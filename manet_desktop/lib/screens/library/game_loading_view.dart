import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/comic_burst.dart';
import '../../widgets/juicy_widgets.dart';
import '../../widgets/player_face_indicator.dart';
import '../home_page/gamepad_state.dart';
import 'face_aquarium.dart';
import 'face_aquarium_sim.dart';
import 'library_browser.dart' show GameCover;

/// Shown from the launch until the game's window is up (the server watches
/// for it): a box the players fill with copies of their faces, one per
/// button press, with a counter and a record to beat, over a footer with
/// the bobbing cover and silly "booting" lines. If it takes long, START (or the button)
/// shows the game anyway.
class GameLoadingView extends StatefulWidget {
  const GameLoadingView({super.key});

  @override
  State<GameLoadingView> createState() => _GameLoadingViewState();
}

class _GameLoadingViewState extends State<GameLoadingView>
    with SingleTickerProviderStateMixin {
  /// After this the "show the game" way out is offered.
  static const Duration _slowAfter = Duration(seconds: 15);

  /// Each game keeps its own record: a quick-loading game and one that takes
  /// a minute aren't the same race.
  late final String _recordKey;

  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  Timer? _timer;
  Timer? _saveRecord;
  final DateTime _shownAt = DateTime.now();
  final AquariumSim _aquarium = AquariumSim();
  /// Bumped on every throw and overflow so only the counter rebuilds.
  final ValueNotifier<int> _throws = ValueNotifier(0);
  /// Best total of earlier loading screens of this game; null until read.
  int? _record;

  @override
  void initState() {
    super.initState();
    final gameId = context.read<SessionController>().snapshot.runningGame?.id;
    _recordKey = 'aquarium_record_${gameId ?? ''}';
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _record = prefs.getInt(_recordKey) ?? 0);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    // The game usually opens mid-throwing: keep a record not saved yet.
    if (_saveRecord?.isActive ?? false) {
      _saveRecord!.cancel();
      _storeRecord();
    }
    _bob.dispose();
    _throws.dispose();
    super.dispose();
  }

  void _onAquariumChanged() {
    _throws.value++;
    final record = _record;
    if (record != null && _aquarium.total > record) {
      _saveRecord?.cancel();
      _saveRecord = Timer(const Duration(seconds: 1), _storeRecord);
    }
  }

  void _storeRecord() {
    final total = _aquarium.total;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setInt(_recordKey, total))
        .catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final session = context.watch<SessionController>();
    final snapshot = session.snapshot;
    final running = snapshot.runningGame;
    final game = session.gameById(running?.id);
    final startedAt = snapshot.launchStartedAt ?? _shownAt;
    final elapsed = DateTime.now().difference(startedAt);
    final lines = strings.loadingLines;
    final line = lines[(elapsed.inMilliseconds ~/ 2600) % lines.length];
    final dots = '.' * (1 + (elapsed.inMilliseconds ~/ 500) % 3);
    final slow = elapsed >= _slowAfter;
    final players = [for (final p in snapshot.players) p.deviceId];

    // Footer: what is opening, bobbing cover and silly lines; when it takes
    // long, the way out.
    final footer = Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      color: AppColors.lightColor,
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _bob,
            builder: (context, child) {
              final t = _bob.value * 2 * math.pi;
              return Transform.translate(
                offset: Offset(0, math.sin(t) * 3),
                child: Transform.rotate(angle: math.sin(t + 1) * 0.06, child: child),
              );
            },
            child: Container(
              width: 50,
              height: 56,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: game == null
                    ? const ColoredBox(color: AppColors.lightColor)
                    : GameCover(game: game),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.loadingGame(running?.name ?? game?.name ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _titleStyle.copyWith(fontSize: 22),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    '$line$dots  ·  ${strings.loadingElapsed(elapsed.inSeconds)}',
                    key: ValueKey(line),
                    style: _bodyStyle,
                  ),
                ),
              ],
            ),
          ),
          if (slow) ...[
            Flexible(
              child: Text(
                strings.loadingSlowHint,
                textAlign: TextAlign.right,
                style: _captionStyle.copyWith(fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            JuicyButton(
              onPressed: session.markGameReady,
              backgroundColor: AppColors.highlightColor,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(strings.loadingShowGame, style: _buttonStyle),
            ),
            const SizedBox(width: 10),
            JuicyButton(
              onPressed: session.stopGame,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(strings.cancel, style: _buttonStyle),
            ),
          ],
        ],
      ),
    );

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: FaceAquarium(
                  deviceIds: players,
                  sim: _aquarium,
                  onChanged: _onAquariumChanged,
                ),
              ),
              // Faces fly in behind the counter.
              Positioned(
                right: 20,
                top: 16,
                child: ValueListenableBuilder<int>(
                  valueListenable: _throws,
                  builder: (context, _, _) => _AquariumCounter(
                    total: _aquarium.total,
                    perPlayer: _aquarium.perPlayer,
                    players: players,
                    record: _record,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _throws,
                    builder: (context, _, _) =>
                        _OverflowCheer(overflows: _aquarium.overflows),
                  ),
                ),
              ),
            ],
          ),
        ),
        footer,
      ],
    );
  }
}

/// The number to beat: the faces thrown in this loading screen, popping on
/// every throw, the record of earlier ones, and who threw how many (most
/// first).
class _AquariumCounter extends StatelessWidget {
  final int total;
  final Map<String, int> perPlayer;
  final List<String> players;
  final int? record;

  const _AquariumCounter({
    required this.total,
    required this.perPlayer,
    required this.players,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final pads = context.read<GamepadState>();
    final best = record ?? 0;
    final beating = best > 0 && total > best;
    final ranking = [...players]
      ..sort((a, b) => (perPlayer[b] ?? 0).compareTo(perPlayer[a] ?? 0));
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: beating ? AppColors.highlightColor : AppColors.lightColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.textPrimary, width: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ComicBopBurst(
            trigger: total,
            burstRadius: 54,
            child: Text('$total', style: _titleStyle.copyWith(fontSize: 52, height: 1.05)),
          ),
          Text(strings.aquariumFaces(total), style: _bodyStyle),
          Text(
            total == 0
                ? strings.aquariumHint
                : beating
                ? strings.aquariumNewRecord
                : strings.aquariumRecord(math.max(best, total)),
            textAlign: TextAlign.center,
            style: total == 0 ? _bodyStyle : _buttonStyle.copyWith(fontSize: 16),
          ),
          if (ranking.isNotEmpty) const SizedBox(height: 8),
          for (final id in ranking)
            if (pads.deviceById(id) case final device?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    PlayerFaceIndicator(face: device.face, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _bodyStyle.copyWith(fontSize: 14),
                      ),
                    ),
                    Text('${perPlayer[id] ?? 0}', style: _buttonStyle),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// "It overflowed!" springing up in the middle each time the box drains.
class _OverflowCheer extends StatelessWidget {
  final int overflows;

  const _OverflowCheer({required this.overflows});

  @override
  Widget build(BuildContext context) {
    if (overflows == 0) return const SizedBox.shrink();
    final text = context.l10n.session.aquariumOverflow;
    return Center(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(overflows),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1700),
        builder: (context, t, child) {
          // Springs in, holds, then fades away.
          final grow = Curves.elasticOut.transform(math.min(1, t / 0.35));
          final fade = t < 0.8 ? 1.0 : 1 - (t - 0.8) / 0.2;
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: -0.08,
              child: Transform.scale(scale: grow, child: child),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.highlightColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.textPrimary, width: 5),
          ),
          child: Text(
            overflows > 1 ? '$text  x$overflows' : text,
            style: _titleStyle.copyWith(fontSize: 44),
          ),
        ),
      ),
    );
  }
}

const TextStyle _titleStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 28,
  color: AppColors.textPrimary,
);

const TextStyle _bodyStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 16,
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
