import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/session_models.dart';
import '../../services/host_api_service.dart';
import '../../services/session_controller.dart';
import '../library/in_game_view.dart';
import '../library/library_view.dart';
import '../library/tournament_view.dart';
import 'lobby_ready_banner.dart';

/// Swaps the main area by session phase, sliding sideways like moving
/// between console screens: lobby -> game library -> playing.
class SessionStage extends StatelessWidget {
  final Widget lobby;
  final PresetCatalog? presetCatalog;

  const SessionStage({super.key, required this.lobby, this.presetCatalog});

  @override
  Widget build(BuildContext context) {
    final phase = context.select<SessionController, SessionPhase>(
      (s) => s.snapshot.phase,
    );
    final child = switch (phase) {
      SessionPhase.lobby => Column(
        children: [
          const LobbyReadyBanner(),
          Expanded(child: lobby),
        ],
      ),
      SessionPhase.library => LibraryView(presetCatalog: presetCatalog),
      SessionPhase.tournament => const TournamentView(),
      SessionPhase.inGame => const InGameView(),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final entering = child.key == ValueKey(phase);
        final offset = Tween<Offset>(
          begin: Offset(entering ? 0.25 : -0.25, 0),
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
