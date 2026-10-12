import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/juicy_widgets.dart';

/// Lobby status strip: how many players are ready, what to press, and the
/// host's shortcut to the game library.
class LobbyReadyBanner extends StatelessWidget {
  const LobbyReadyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final snapshot = session.snapshot;
    final strings = context.l10n.session;
    if (snapshot.players.isEmpty) return const SizedBox.shrink();

    final String message;
    final IconData icon;
    if (!snapshot.menuInput) {
      message = strings.controlsInBackground;
      icon = Icons.sports_esports_outlined;
    } else if (snapshot.allReady) {
      message = strings.allReady;
      icon = Icons.celebration_rounded;
    } else {
      message = strings.readyPrompt(
        snapshot.readyCount,
        snapshot.players.length,
      );
      icon = Icons.hourglass_top_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: snapshot.allReady && snapshot.menuInput
            ? AppColors.highlightColor
            : AppColors.lightColor,
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
              style: const TextStyle(
                fontFamily: 'momo',
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
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
                Text(
                  strings.chooseGame,
                  style: const TextStyle(
                    fontFamily: 'momo',
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
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
