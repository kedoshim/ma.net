import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/juicy_widgets.dart';

/// Shown when the host looks at MaNet while a game is running.
class InGameView extends StatelessWidget {
  const InGameView({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.session;
    final session = context.watch<SessionController>();
    final running = session.snapshot.runningGame;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.lightColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.textPrimary, width: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sports_esports_rounded,
              size: 48,
              color: AppColors.textPrimary,
            ),
            const SizedBox(height: 12),
            Text(
              strings.playing(running?.name ?? ''),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'momo',
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              running?.tracked == false
                  ? strings.untrackedHint
                  : strings.playingHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'momo',
                fontSize: 14,
                color: AppColors.textPrimary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (running?.tracked ?? false)
                  JuicyButton(
                    onPressed: session.stopGame,
                    backgroundColor: Colors.red.shade200,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Text(strings.closeGame, style: _buttonStyle),
                  ),
                JuicyButton(
                  onPressed: session.returnFromGame,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Text(strings.returnToLobby, style: _buttonStyle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const TextStyle _buttonStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 14,
  color: AppColors.textPrimary,
);
