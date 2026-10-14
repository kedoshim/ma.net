import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/session_models.dart';
import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/juicy_widgets.dart';
import '../../widgets/player_face_indicator.dart';
import '../home_page/gamepad_state.dart';
import 'face_playground.dart';

const TextStyle _title = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 30,
  color: AppColors.textPrimary,
);

const TextStyle _body = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 16,
  color: AppColors.textPrimary,
);

/// Console mode, more players than the game's seats: everyone picks a side
/// (play now / start on the bench) with their face, then a quick minigame
/// (dedanha or zerinho ou um) decides who plays first.
class LineupView extends StatelessWidget {
  const LineupView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final lineup = session.snapshot.lineup;
    final strings = context.l10n.session;
    if (lineup == null) return const SizedBox.shrink();
    final game = session.games.where((g) => g.id == lineup.gameId).firstOrNull;

    final Widget body = switch (lineup.stage) {
      'choose' => _ChooseStage(lineup: lineup),
      'announce' || 'pick' || 'reveal' => _MinigameStage(lineup: lineup),
      _ => _DoneStage(lineup: lineup),
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      switch (lineup.stage) {
                        'choose' => strings.lineupTitle,
                        'done' => strings.lineupDone,
                        _ => lineup.game == 'dedanha' ? strings.lineupDedanha : strings.lineupZerinho,
                      },
                      style: _title,
                    ),
                    Text(
                      switch (lineup.stage) {
                        'choose' => '${strings.lineupSeats(game?.name ?? '', lineup.seats)} · ${strings.lineupChooseHint}',
                        'announce' || 'pick' || 'reveal' => [
                            lineup.game == 'dedanha' ? strings.lineupDedanhaHint : strings.lineupZerinhoHint,
                            lineup.mode == 'out'
                                ? strings.lineupModeOut(lineup.needed)
                                : strings.lineupModeIn(lineup.needed),
                          ].join(' · '),
                        _ => strings.lineupSeats(game?.name ?? '', lineup.seats),
                      },
                      style: _body.copyWith(fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
              if (lineup.endsAt != null) _SecondsLeft(endsAt: lineup.endsAt!),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: body),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: JuicyButton(
              onPressed: session.cancelLineup,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(strings.lineupCancel, style: _body),
            ),
          ),
        ],
      ),
    );
  }
}

/// Big countdown number in the corner.
class _SecondsLeft extends StatefulWidget {
  final DateTime endsAt;

  const _SecondsLeft({required this.endsAt});

  @override
  State<_SecondsLeft> createState() => _SecondsLeftState();
}

class _SecondsLeftState extends State<_SecondsLeft> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.endsAt.difference(DateTime.now()).inMilliseconds / 1000;
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.lightColor,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textPrimary, width: 3),
      ),
      child: Text('${math.max(0, left.ceil())}', style: _title.copyWith(fontSize: 26)),
    );
  }
}

/// Faces roll to the left (play now) or right (start on the bench) half.
class _ChooseStage extends StatelessWidget {
  final LineupState lineup;

  const _ChooseStage({required this.lineup});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    final strings = context.l10n.session;
    final playCount = lineup.zones.values.where((z) => z == 'play').length;
    final benchCount = lineup.zones.values.where((z) => z == 'bench').length;

    Widget side(String label, int count, bool highlighted) => Expanded(
      child: Container(
        color: highlighted
            ? AppColors.highlightColor.withValues(alpha: 0.45)
            : AppColors.lightColor,
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          children: [
            Text(label, style: _title.copyWith(fontSize: 24)),
            Text('$count', style: _title.copyWith(fontSize: 20)),
          ],
        ),
      ),
    );

    // Three bands: play now | undecided | bench. Faces drop in the middle
    // one, so nobody has chosen until they walk.
    return FacePlayground(
      deviceIds: lineup.queue,
      nameTags: true,
      spawnOf: (id, size) {
        final i = lineup.queue.indexOf(id);
        final n = lineup.queue.length;
        final third = size.width / 3;
        final x = third + third * (i + 1) / (n + 1);
        return PlaygroundSpawn(Offset(x, kPlaygroundFaceRadius + 4));
      },
      background: (context, size) => Row(
        children: [
          side(strings.lineupPlayNow, playCount, true),
          Container(width: 4, color: AppColors.textPrimary),
          Expanded(child: Container(color: AppColors.screenBackground)),
          Container(width: 4, color: AppColors.textPrimary),
          side(strings.lineupBench, benchCount, false),
        ],
      ),
      zoneOf: (center, size) {
        if (center.dx < size.width / 3) return 'play';
        if (center.dx > size.width * 2 / 3) return 'bench';
        return null;
      },
      onZoneChanged: (id, zone) => unawaited(session.setLineupZone(id, zone)),
    );
  }
}

/// The candidates in a circle; picks are revealed and, for dedanha, a
/// marker counts around the circle to the person it lands on.
class _MinigameStage extends StatefulWidget {
  final LineupState lineup;

  const _MinigameStage({required this.lineup});

  @override
  State<_MinigameStage> createState() => _MinigameStageState();
}

class _MinigameStageState extends State<_MinigameStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _count = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _maybeCount();
  }

  @override
  void didUpdateWidget(covariant _MinigameStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lineup.stage != widget.lineup.stage ||
        oldWidget.lineup.round != widget.lineup.round) {
      _maybeCount();
    }
  }

  void _maybeCount() {
    final l = widget.lineup;
    if (l.stage != 'reveal' || l.game != 'dedanha') {
      _count.value = 0;
      return;
    }
    final total = (l.result?['total'] as int?) ?? 0;
    _count.duration = Duration(milliseconds: (total * 180).clamp(600, 2600));
    _count.forward(from: 0);
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lineup;
    final strings = context.l10n.session;
    final gamepads = context.watch<GamepadState>();
    final reveal = l.stage == 'reveal';
    final result = l.result ?? const {};
    final decided = reveal ? (result['decided'] as List<dynamic>? ?? const []).cast<String>() : const <String>[];
    final minority = reveal ? (result['minority'] as List<dynamic>? ?? const []).cast<String>() : const <String>[];
    final total = (result['total'] as int?) ?? 0;
    final people = l.candidates;

    String? caption;
    if (reveal) {
      if (l.game == 'dedanha') {
        caption = strings.lineupTotal(total);
      } else if (result['tie'] == true) {
        caption = strings.lineupTie;
      } else if (result['narrowTo'] != null) {
        caption = strings.lineupNarrow;
      }
    } else if (l.stage == 'announce') {
      caption = strings.lineupGetReady;
    } else {
      caption = strings.lineupPicked(l.picked.length, people.length);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        final radius = math.max(60.0, math.min(constraints.maxWidth, constraints.maxHeight) / 2 - 80);
        const face = 76.0;

        return AnimatedBuilder(
          animation: _count,
          builder: (context, _) {
            // Dedanha: the marker hops one person per step.
            final steps = (_count.value * total).floor();
            final marker = reveal && l.game == 'dedanha' && people.isNotEmpty
                ? steps % people.length
                : null;
            final landed = reveal && (l.game != 'dedanha' || _count.isCompleted);

            return Stack(
              children: [
                if (caption != null)
                  Positioned.fill(
                    child: Center(child: Text(caption, style: _title.copyWith(fontSize: 26))),
                  ),
                for (var i = 0; i < people.length; i++)
                  if (gamepads.deviceById(people[i]) case final device?)
                    () {
                      final angle = -math.pi / 2 + 2 * math.pi * i / people.length;
                      final p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
                      final id = people[i];
                      final isDecided = landed && decided.contains(id);
                      final pick = reveal ? (l.picks ?? const <String, int>{})[id] : null;
                      final highlighted = marker == i ||
                          isDecided ||
                          (reveal && l.game == 'zerinho' && minority.contains(id));
                      return Positioned(
                        left: p.dx - 70,
                        top: p.dy - face / 2 - 30,
                        width: 140,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 30,
                              child: pick != null
                                  ? Text('$pick', style: _title.copyWith(fontSize: 24))
                                  : (!reveal && l.picked.contains(id)
                                      ? const Icon(Icons.check_circle_rounded, color: AppColors.textPrimary)
                                      : null),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: highlighted ? AppColors.highlightColor : Colors.transparent,
                                border: Border.all(
                                  color: highlighted ? AppColors.textPrimary : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: PlayerFaceIndicator(face: device.face, size: face),
                            ),
                            Text(device.name, style: _body, maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (isDecided)
                              Text(
                                l.mode == 'out' ? strings.lineupGoesOut : strings.lineupGoesIn,
                                style: _body.copyWith(fontSize: 14),
                              ),
                          ],
                        ),
                      );
                    }(),
              ],
            );
          },
        );
      },
    );
  }
}

/// Who plays and who waits on the bench.
class _DoneStage extends StatelessWidget {
  final LineupState lineup;

  const _DoneStage({required this.lineup});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final gamepads = context.watch<GamepadState>();

    Widget group(String title, List<String> ids, bool highlighted) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.highlightColor.withValues(alpha: 0.45) : AppColors.lightColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.textPrimary, width: 3),
        ),
        child: Column(
          children: [
            Text(title, style: _title.copyWith(fontSize: 24)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: [
                for (final id in ids)
                  if (gamepads.deviceById(id) case final device?)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlayerFaceIndicator(face: device.face, size: 72),
                        Text(device.name, style: _body),
                      ],
                    ),
              ],
            ),
          ],
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        group(strings.lineupPlaying, lineup.chosen, true),
        const SizedBox(width: 20),
        group(strings.lineupOnBench, lineup.bench, false),
      ],
    );
  }
}
