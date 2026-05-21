import 'package:flutter/material.dart';

import '../../models/player_face.dart';
import '../../theme/app_colors.dart';
import '../../widgets/control_button.dart';
import '../../widgets/joystick.dart';
import 'controller_screen_widgets.dart';

typedef MouseButtonStateCallback = void Function(String button, String state);

class ControllerMouseView extends StatelessWidget {
  const ControllerMouseView({
    super.key,
    required this.mouseModeOwned,
    required this.mouseModeOwnerName,
    required this.onPointerMoved,
    required this.onPointerReleased,
    required this.onMouseButtonStateChanged,
    required this.onScroll,
    required this.onToggleWindowVisibility,
    required this.onExit,
    required this.totalSlots,
    required this.playerIndex,
    required this.status,
    required this.playerFace,
    required this.centerPulseExpanded,
    required this.onPulseCycleEnd,
  });

  final bool mouseModeOwned;
  final String? mouseModeOwnerName;
  final ValueChanged<Offset> onPointerMoved;
  final VoidCallback onPointerReleased;
  final MouseButtonStateCallback onMouseButtonStateChanged;
  final ValueChanged<double> onScroll;
  final VoidCallback onToggleWindowVisibility;
  final VoidCallback onExit;
  final int totalSlots;
  final int? playerIndex;
  final String status;
  final PlayerFaceData playerFace;
  final bool centerPulseExpanded;
  final VoidCallback onPulseCycleEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'cursor',
                  style: TextStyle(
                    fontFamily: 'pico',
                    fontSize: 16,
                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                Joystick(
                  size: 250,
                  onChanged: (x, y) => onPointerMoved(Offset(x, y)),
                  onReleased: onPointerReleased,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: ControllerModeHub(
                icon: Icons.mouse_outlined,
                title: 'mouse mode',
                onTap: onExit,
                totalSlots: totalSlots,
                selectedPlayerIndex: playerIndex,
                status: status,
                playerFace: playerFace,
                pulse: false,
                centerPulseExpanded: centerPulseExpanded,
                onPulseCycleEnd: onPulseCycleEnd,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: ControlButton(
                label: '',
                width: 84,
                height: 58,
                icon: const Icon(
                  Icons.fullscreen_exit_rounded,
                  color: AppColors.textPrimary,
                ),
                onStateChange: (state) {
                  if (state == 'up') {
                    onToggleWindowVisibility();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              Expanded(
                flex: 5,
                child: _MouseScrollStrip(onScroll: onScroll),
              ),
              const SizedBox(height: 16),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Expanded(
                      child: ControlButton(
                        label: 'LEFT',
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(28),
                        onStateChange: (state) =>
                            onMouseButtonStateChanged('left', state),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ControlButton(
                        label: 'RIGHT',
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(28),
                        onStateChange: (state) =>
                            onMouseButtonStateChanged('right', state),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MouseScrollStrip extends StatelessWidget {
  const _MouseScrollStrip({required this.onScroll});

  final ValueChanged<double> onScroll;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        final dragDelta = details.primaryDelta ?? 0;
        if (dragDelta.abs() < 1) {
          return;
        }
        onScroll((-dragDelta / 32).clamp(-1.2, 1.2));
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.backgroundColor.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.textPrimary,
            width: AppColors.borderThickness,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Icon(
              Icons.keyboard_arrow_up_rounded,
              color: AppColors.textPrimary,
              size: 34,
            ),
            Text(
              'scroll',
              style: TextStyle(
                fontFamily: 'pico',
                fontSize: 16,
                color: AppColors.textPrimary.withValues(alpha: 0.85),
              ),
            ),
            Flexible(
              child: Container(
                width: 56,
                height: 98,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.highlightColor.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.swap_vert_rounded,
                  color: AppColors.textPrimary,
                  size: 30,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textPrimary,
              size: 34,
            ),
          ],
        ),
      ),
    );
  }
}
