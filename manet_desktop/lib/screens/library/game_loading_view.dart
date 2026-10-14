import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/juicy_widgets.dart';
import 'face_playground.dart';
import 'library_browser.dart' show GameCover;

/// Shown from the launch until the game's window is up (the server watches
/// for it): the cover bobbing, silly "booting" lines, and the players' faces
/// to jump around with while they wait. If it takes long, START (or the
/// button) shows the game anyway.
class GameLoadingView extends StatefulWidget {
  const GameLoadingView({super.key});

  @override
  State<GameLoadingView> createState() => _GameLoadingViewState();
}

class _GameLoadingViewState extends State<GameLoadingView>
    with SingleTickerProviderStateMixin {
  /// After this the "show the game" way out is offered.
  static const Duration _slowAfter = Duration(seconds: 15);

  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  Timer? _timer;
  final DateTime _shownAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bob.dispose();
    super.dispose();
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

    return Column(
      children: [
        Expanded(
          flex: 6,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final coverWidth = (constraints.maxHeight * 0.5).clamp(90.0, 220.0);
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _bob,
                      builder: (context, child) {
                        final t = _bob.value * 2 * math.pi;
                        return Transform.translate(
                          offset: Offset(0, math.sin(t) * 8),
                          child: Transform.rotate(
                            angle: math.sin(t + 1) * 0.04,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: coverWidth,
                        height: coverWidth * 1.1,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: game == null
                              ? const ColoredBox(color: AppColors.lightColor)
                              : GameCover(game: game),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      strings.loadingGame(running?.name ?? game?.name ?? ''),
                      textAlign: TextAlign.center,
                      style: _titleStyle,
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        '$line$dots',
                        key: ValueKey(line),
                        style: _bodyStyle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.loadingElapsed(elapsed.inSeconds),
                      style: _captionStyle,
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      child: slow
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(strings.loadingSlowHint, style: _bodyStyle),
                                  JuicyButton(
                                    onPressed: session.markGameReady,
                                    backgroundColor: AppColors.highlightColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    child: Text(strings.loadingShowGame, style: _buttonStyle),
                                  ),
                                  JuicyButton(
                                    onPressed: session.stopGame,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    child: Text(strings.cancel, style: _buttonStyle),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 4,
          child: FacePlayground(
            deviceIds: [for (final p in snapshot.players) p.deviceId],
          ),
        ),
      ],
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
