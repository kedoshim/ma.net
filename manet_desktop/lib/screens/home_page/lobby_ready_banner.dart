import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/session_models.dart';
import '../../services/sound_effect_service.dart';
import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/juicy_widgets.dart';

/// Lobby status strip: how many players are ready, what to press, and the
/// host's shortcut to the game library. When everyone is ready it turns into
/// a 5 second countdown bar before the game selection opens.
class LobbyReadyBanner extends StatelessWidget {
  const LobbyReadyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final snapshot = session.snapshot;
    final strings = context.l10n.session;
    if (snapshot.players.isEmpty) return const SizedBox.shrink();

    final countdown = snapshot.lobbyCountdown;
    if (countdown != null) {
      return _LobbyCountdownBar(
        key: ValueKey(countdown.endsAt),
        countdown: countdown,
      );
    }

    final message = snapshot.allReady
        ? strings.allReady
        : strings.readyPrompt(snapshot.readyCount, snapshot.players.length);
    final icon = snapshot.allReady
        ? Icons.celebration_rounded
        : Icons.hourglass_top_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.lightColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.textPrimary, width: 2.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _bannerText,
            ),
          ),
          const SizedBox(width: 12),
          JuicyButton(
            onPressed: session.openLibrary,
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.grid_view_rounded,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 6),
                Text(strings.chooseGame, style: _bannerText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _bannerText = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 15,
  color: AppColors.textPrimary,
);

/// Everyone is ready: a draining bar with a bouncing number per second.
class _LobbyCountdownBar extends StatefulWidget {
  final LobbyCountdown countdown;

  const _LobbyCountdownBar({super.key, required this.countdown});

  @override
  State<_LobbyCountdownBar> createState() => _LobbyCountdownBarState();
}

class _LobbyCountdownBarState extends State<_LobbyCountdownBar>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _left = 1;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration _) {
    final total = widget.countdown.seconds * 1000;
    final remaining = widget.countdown.endsAt
        .difference(DateTime.now())
        .inMilliseconds
        .clamp(0, total.round());
    final seconds = (remaining / 1000).ceil();
    if (seconds != _seconds) {
      try {
        if (seconds > 0) {
          SoundEffectService.instance.playCountdownTick();
        } else {
          SoundEffectService.instance.playCountdownGo();
        }
      } catch (_) {}
    }
    setState(() {
      _left = total == 0 ? 0 : remaining / total;
      _seconds = seconds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.lightColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.textPrimary, width: 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // The highlight drains from right to left.
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _left,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: AppColors.textPrimary, width: 2.5),
                  ),
                ),
                child: ColoredBox(color: AppColors.highlightColor),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.celebration_rounded,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      strings.lobbyCountdown,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bannerText.copyWith(fontSize: 17),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    key: ValueKey(_seconds),
                    tween: Tween(begin: 1.8, end: 1),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) => Transform.rotate(
                      angle: (scale - 1) * 0.35,
                      child: Transform.scale(scale: scale, child: child),
                    ),
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.lightColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.textPrimary,
                          width: 3,
                        ),
                      ),
                      child: Text(
                        '${_seconds.clamp(1, 99)}',
                        textAlign: TextAlign.center,
                        style: _bannerText.copyWith(fontSize: 26, height: 1.0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "READY" pill shown on a player's slot card.
class ReadyBadge extends StatelessWidget {
  final double fontSize;
  const ReadyBadge({super.key, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: fontSize * 0.6,
          vertical: fontSize * 0.2,
        ),
        decoration: BoxDecoration(
          color: Colors.green.shade400,
          borderRadius: BorderRadius.circular(fontSize),
          border: Border.all(color: AppColors.textPrimary, width: 2),
        ),
        child: Text(
          context.l10n.session.ready,
          style: TextStyle(
            fontFamily: 'momo',
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
