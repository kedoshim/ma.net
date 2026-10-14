import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/session_models.dart';
import '../../services/host_api_service.dart';
import '../../services/session_controller.dart';
import '../library/game_loading_view.dart';
import '../library/in_game_view.dart';
import '../library/library_view.dart';
import '../library/lineup_view.dart';
import '../library/tournament_view.dart';
import '../../theme/app_colors.dart';
import '../../widgets/juicy_widgets.dart';
import 'lobby_ready_banner.dart';

/// Swaps the main area by session phase, sliding sideways like moving
/// between console screens: lobby -> game library -> playing. Going forward
/// the new screen comes from the right; going back (e.g. library -> lobby)
/// it comes from the left.
class SessionStage extends StatefulWidget {
  final Widget lobby;
  final PresetCatalog? presetCatalog;

  const SessionStage({super.key, required this.lobby, this.presetCatalog});

  @override
  State<SessionStage> createState() => _SessionStageState();
}

class _SessionStageState extends State<SessionStage> {
  SessionPhase? _shown;
  bool _forward = true;

  @override
  Widget build(BuildContext context) {
    final lobby = widget.lobby;
    final presetCatalog = widget.presetCatalog;
    final phase = context.select<SessionController, SessionPhase>(
      (s) => s.snapshot.phase,
    );
    if (phase != _shown) {
      // Enum order is the screen order: lobby, library, tournament, lineup, game.
      _forward = _shown == null || phase.index > _shown!.index;
      _shown = phase;
    }
    final forward = _forward;
    final child = switch (phase) {
      SessionPhase.lobby when context.select<SessionController, bool>((s) => s.snapshot.consoleMode) =>
        // Console lobby: one edge-to-edge scene; the animated countdown bar
        // drops over its top only while the game selection counts down.
        Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: lobby),
                  const Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FractionallySizedBox(widthFactor: 0.5, child: _ConsoleCountdown()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      SessionPhase.lobby => Column(
        children: [
          const LobbyReadyBanner(),
          Expanded(child: lobby),
          const _EmptyLobbyFooter(),
        ],
      ),
      SessionPhase.library => LibraryView(presetCatalog: presetCatalog),
      SessionPhase.tournament => const TournamentView(),
      SessionPhase.lineup => const LineupView(),
      SessionPhase.inGame
          when !context.select<SessionController, bool>((s) => s.snapshot.gameReady) =>
        const GameLoadingView(),
      SessionPhase.inGame => const InGameView(),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        // The outgoing screen runs this animation backwards: it leaves on
        // the side opposite to where the new one comes from.
        final entering = child.key == ValueKey(phase);
        final fromRight = entering == forward;
        final offset = Tween<Offset>(
          begin: Offset(fromRight ? 0.25 : -0.25, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(phase), child: child),
    );
  }
}

/// With nobody connected the ready banner (and its "pick a game" button) is
/// hidden; this footer lets the host browse the library with the mouse.
class _EmptyLobbyFooter extends StatelessWidget {
  const _EmptyLobbyFooter();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.snapshot.players.isNotEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: JuicyButton(
          onPressed: session.openLibrary,
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.grid_view_rounded, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 6),
              Text(
                context.l10n.session.chooseGame,
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The lobby's animated countdown bar, only while it runs.
class _ConsoleCountdown extends StatelessWidget {
  const _ConsoleCountdown();

  @override
  Widget build(BuildContext context) {
    final running = context.select<SessionController, bool>(
      (s) => s.snapshot.lobbyCountdown != null,
    );
    // Slide + fade (no clipping, so the bar's border and shadow stay whole).
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: running ? const LobbyReadyBanner() : const SizedBox(width: double.infinity),
    );
  }
}
