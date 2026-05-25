import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/player_face.dart';
import '../../services/network_discovery_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/player_face_indicator.dart';
import 'controller_screen_types.dart';

class ControllerPlayerIndicator extends StatelessWidget {
  const ControllerPlayerIndicator({
    super.key,
    required this.totalSlots,
    required this.selectedPlayerIndex,
    required this.status,
    required this.playerFace,
  });

  final int totalSlots;
  final int? selectedPlayerIndex;
  final String status;
  final PlayerFaceData playerFace;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = selectedPlayerIndex != null
        ? selectedPlayerIndex! - 1
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = totalSlots <= 4 ? (totalSlots > 0 ? totalSlots : 1) : 4;
        final rows = (totalSlots / columns).ceil();
        final squareSize = ((constraints.maxWidth - (columns * 8)) / columns)
            .clamp(12.0, 22.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(rows, (rowIndex) {
            final rowItemCount = (rowIndex == rows - 1)
                ? totalSlots - (rowIndex * columns)
                : columns;

            return Padding(
              padding: EdgeInsets.only(bottom: rowIndex < rows - 1 ? 6.0 : 0),
              child: _IndicatorRow(
                selectedIndex: selectedIndex,
                offset: rowIndex * columns,
                count: rowItemCount,
                squareSize: squareSize,
                status: status,
                playerFace: playerFace,
              ),
            );
          }),
        );
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
      return const Text(
        'procurando...',
        style: TextStyle(
          fontSize: 18,
          color: AppColors.textPrimary,
          fontFamily: 'pico',
        ),
      );
    }

    if (connectionState == ControllerConnectionState.disconnected) {
      return const Text(
        'desconectado',
        style: TextStyle(
          fontSize: 18,
          color: AppColors.textPrimary,
          fontFamily: 'pico',
        ),
      );
    }

    if (connectionState == ControllerConnectionState.multipleHostsFound) {
      return const Text(
        'selecionar host',
        style: TextStyle(
          fontSize: 18,
          color: AppColors.textPrimary,
          fontFamily: 'pico',
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
            fontFamily: 'pico',
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
    required this.status,
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
  final String status;
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
            fontFamily: 'pico',
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
        SizedBox(
          width: 96,
          child: ControllerPlayerIndicator(
            totalSlots: totalSlots,
            selectedPlayerIndex: selectedPlayerIndex,
            status: status,
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
                const Text(
                  'Varios Hosts Encontrados',
                  style: TextStyle(
                    fontFamily: 'pico',
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
                                fontFamily: 'pico',
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              host.ip,
                              style: TextStyle(
                                fontFamily: 'pico',
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
                    label: const Text(
                      'Escanear QR em vez disso',
                      style: TextStyle(
                        fontFamily: 'pico',
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

class _IndicatorRow extends StatelessWidget {
  const _IndicatorRow({
    required this.selectedIndex,
    required this.offset,
    required this.count,
    required this.squareSize,
    required this.status,
    required this.playerFace,
  });

  final int? selectedIndex;
  final int offset;
  final int count;
  final double squareSize;
  final String status;
  final PlayerFaceData playerFace;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final position = offset + index;
        final isActive = selectedIndex == position;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedOpacity(
            opacity: isActive && status == 'Conectado' ? 1 : 0.4,
            duration: const Duration(milliseconds: 180),
            child: isActive && status == 'Conectado'
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
          ),
        );
      }),
    );
  }
}
