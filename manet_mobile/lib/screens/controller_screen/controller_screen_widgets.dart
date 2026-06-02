import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/player_face.dart';
import '../../services/network_discovery_service.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/player_face_indicator.dart';
import '../../widgets/juicy_widgets.dart';
import 'controller_screen_types.dart';

class ControllerPlayerIndicator extends StatelessWidget {
  const ControllerPlayerIndicator({
    super.key,
    required this.totalSlots,
    required this.selectedPlayerIndex,
    required this.isConnected,
    required this.playerFace,
    this.hasVacantSlot = false,
    this.onJoinGame,
  });

  final int totalSlots;
  final int? selectedPlayerIndex;
  final bool isConnected;
  final PlayerFaceData playerFace;
  final bool hasVacantSlot;
  final VoidCallback? onJoinGame;

  @override
  Widget build(BuildContext context) {
    if (selectedPlayerIndex == null && hasVacantSlot) {
      return JuicyButton(
        onTap: onJoinGame,
        backgroundColor: AppColors.highlightColor,
        borderRadius: 16.0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          context.l10n.status.enteringGame,
          style: const TextStyle(
            fontFamily: 'momo',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      );
    }

    final selectedIndex = selectedPlayerIndex != null
        ? selectedPlayerIndex! - 1
        : null;

    if (totalSlots > 12) {
      final isWaiting = selectedPlayerIndex == null;
      final pLabel = isWaiting ? context.l10n.status.waitingForSlot : 'p$selectedPlayerIndex';

      return AnimatedOpacity(
        opacity: isConnected ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 180),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(
              color: AppColors.textPrimary,
              width: AppColors.borderThickness,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isConnected) ...[
                PlayerFaceIndicator(
                  face: playerFace,
                  size: 16,
                  roundedSquare: true,
                  borderColor: AppColors.textPrimary,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                pLabel,
                style: const TextStyle(
                  fontFamily: 'momo',
                  fontSize: 18,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final int safeTotal = totalSlots > 0 ? totalSlots : 1;
        final int columns = safeTotal > 6 ? 6 : safeTotal;
        const double spacing = 6.0;
        const double runSpacing = 6.0;

        final double maxSquareSize = constraints.maxWidth.isFinite
            ? ((constraints.maxWidth - ((columns - 1) * spacing)) / columns)
            : 22.0;

        final double squareSize = maxSquareSize.clamp(12.0, 22.0);
        final double expectedWidth =
            columns * squareSize + (columns - 1) * spacing;

        final isWaiting = selectedPlayerIndex == null;

        final grid = SizedBox(
          width: expectedWidth,
          child: Wrap(
            alignment: WrapAlignment.start,
            spacing: spacing,
            runSpacing: runSpacing,
            children: List.generate(safeTotal, (index) {
              final isActive = selectedIndex == index;

              return AnimatedOpacity(
                opacity: isActive && isConnected ? 1 : 0.4,
                duration: const Duration(milliseconds: 180),
                child: isActive && isConnected
                    ? PlayerFaceIndicator(
                        face: playerFace,
                        size: squareSize,
                        roundedSquare: true,
                        borderColor: AppColors.textPrimary,
                      )
                    : Container(
                        width: squareSize,
                        height: squareSize,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(
                            color: AppColors.textPrimary,
                            width: AppColors.borderThickness,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
              );
            }),
          ),
        );

        if (isWaiting) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              grid,
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerFaceIndicator(
                      face: playerFace,
                      size: 16,
                      roundedSquare: true,
                      borderColor: AppColors.textPrimary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.status.waitingForSlot,
                      style: const TextStyle(
                        fontFamily: 'momo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return grid;
      },
    );
  }
}

class ControllerCenterStatus extends StatelessWidget {
  const ControllerCenterStatus({
    super.key,
    required this.connectionState,
    required this.status,
    required this.playerFace,
    required this.playerColor,
  });

  final ControllerConnectionState connectionState;
  final String status;
  final PlayerFaceData playerFace;
  final Color? playerColor;

  @override
  Widget build(BuildContext context) {
    if (connectionState == ControllerConnectionState.searching) {
      return Text(
        context.l10n.status.searching,
        style: const TextStyle(
          fontSize: 18,
          color: AppColors.textPrimary,
          fontFamily: 'momo',
        ),
      );
    }

    if (connectionState == ControllerConnectionState.disconnected) {
      return Text(
        context.l10n.status.disconnected,
        style: const TextStyle(
          fontSize: 18,
          color: AppColors.textPrimary,
          fontFamily: 'momo',
        ),
      );
    }

    if (connectionState == ControllerConnectionState.multipleHostsFound) {
      return Text(
        context.l10n.status.multipleHostsFound,
        style: const TextStyle(
          fontSize: 18,
          color: AppColors.textPrimary,
          fontFamily: 'momo',
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (playerColor != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PlayerFaceIndicator(
              face: playerFace,
              size: 20,
              roundedSquare: true,
              borderColor: AppColors.textPrimary,
            ),
          ),
        Text(
          status,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            color: AppColors.textPrimary,
            fontFamily: 'momo',
          ),
        ),
      ],
    );
  }
}

class ControllerModeHub extends StatelessWidget {
  const ControllerModeHub({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    required this.totalSlots,
    required this.selectedPlayerIndex,
    required this.isConnected,
    required this.playerFace,
    this.pulse = false,
    required this.centerPulseExpanded,
    required this.onPulseCycleEnd,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final int totalSlots;
  final int? selectedPlayerIndex;
  final bool isConnected;
  final PlayerFaceData playerFace;
  final bool pulse;
  final bool centerPulseExpanded;
  final VoidCallback onPulseCycleEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            color: AppColors.textPrimary,
            fontFamily: 'momo',
          ),
        ),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 1,
            end: pulse && centerPulseExpanded ? 1.08 : 0.96,
          ),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
          onEnd: () {
            if (pulse) {
              onPulseCycleEnd();
            }
          },
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(26),
            child: Ink(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppColors.highlightColor.withValues(alpha: 0.26),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.textPrimary,
                  width: AppColors.borderThickness,
                ),
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 36),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxWidth: 180),
          child: ControllerPlayerIndicator(
            totalSlots: totalSlots,
            selectedPlayerIndex: selectedPlayerIndex,
            isConnected: isConnected,
            playerFace: playerFace,
          ),
        ),
      ],
    );
  }
}

class MultipleHostsOverlay extends StatelessWidget {
  const MultipleHostsOverlay({
    super.key,
    required this.hosts,
    required this.onHostSelected,
    this.onOpenQrScanner,
  });

  final List<DiscoveredHost> hosts;
  final ValueChanged<DiscoveredHost> onHostSelected;
  final VoidCallback? onOpenQrScanner;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.screenBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textPrimary,
                width: AppColors.borderThickness,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.status.multipleHostsTitle,
                  style: const TextStyle(
                    fontFamily: 'momo',
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ...hosts.map(
                  (host) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.highlightColor,
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: AppColors.textPrimary,
                            width: 2,
                          ),
                        ),
                      ),
                      onPressed: () => onHostSelected(host),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              host.name,
                              style: const TextStyle(
                                fontFamily: 'momo',
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              host.ip,
                              style: TextStyle(
                                fontFamily: 'momo',
                                fontSize: 10,
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!kIsWeb && onOpenQrScanner != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(
                      Icons.qr_code_scanner,
                      color: AppColors.textPrimary,
                    ),
                    label: Text(
                      context.l10n.scanner.qrScannerInstead,
                      style: const TextStyle(
                        fontFamily: 'momo',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onPressed: onOpenQrScanner,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
