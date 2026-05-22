import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/player_face.dart';
import '../../theme/app_colors.dart';
import '../../widgets/control_button.dart';
import 'controller_screen_widgets.dart';
import '../../widgets/quick_actions_widget.dart';

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
    required this.onQuickAction,
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
  final ValueChanged<String> onQuickAction;
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
          child: _TouchpadSurface(
            onPointerMoved: onPointerMoved,
            onPointerReleased: onPointerReleased,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QuickActionsMenu(
                    enabled: mouseModeOwned,
                    onAction: onQuickAction,
                  ),
                  const SizedBox(height: 12),
                  ControlButton(
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
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              Expanded(flex: 5, child: _MouseScrollStrip(onScroll: onScroll)),
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

class _TouchpadSurface extends StatefulWidget {
  const _TouchpadSurface({
    required this.onPointerMoved,
    required this.onPointerReleased,
  });

  final ValueChanged<Offset> onPointerMoved;
  final VoidCallback onPointerReleased;

  @override
  State<_TouchpadSurface> createState() => _TouchpadSurfaceState();
}

class _TouchpadSurfaceState extends State<_TouchpadSurface> {
  bool _isPressed = false;
  Offset? _fingerPosition;
  Timer? _stopTimer;
  Offset _lastSent = Offset.zero;

  // Adjust this value to change the touchpad sensitivity.
  // Lower values make the cursor slower, higher values make it faster.
  // (The previous default was equivalent to 1.0).
  final double _sensitivity = 0.5;

  void _sendVelocity(Offset velocity) {
    if (_lastSent == velocity) return;
    _lastSent = velocity;
    widget.onPointerMoved(velocity);
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _isPressed = true;
      _fingerPosition = details.localPosition;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _fingerPosition = details.localPosition;
    });

    // Convert raw drag delta to a continuous movement equivalent velocity.
    // The base divisor (3.0) smooths it, and _sensitivity fine-tunes the speed.
    // Y is inverted (-details.delta.dy) to mimic standard gamepad logic
    // where UP typically yields a positive vector.
    final vx = (details.delta.dx / 3.0) * _sensitivity;
    final vy = (-details.delta.dy / 3.0) * _sensitivity;

    _sendVelocity(Offset(vx, vy));

    // Start a tiny timer to snap velocity to zero if the finger stops moving.
    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(milliseconds: 45), () {
      _sendVelocity(Offset.zero);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    _stopTimer?.cancel();
    _sendVelocity(Offset.zero);
    setState(() {
      _isPressed = false;
      _fingerPosition = null;
    });
    widget.onPointerReleased();
  }

  void _handlePanCancel() {
    _stopTimer?.cancel();
    _sendVelocity(Offset.zero);
    setState(() {
      _isPressed = false;
      _fingerPosition = null;
    });
    widget.onPointerReleased();
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onPanCancel: _handlePanCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: _isPressed
                ? AppColors.highlightColor.withValues(alpha: 0.12)
                : AppColors.backgroundColor.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: _isPressed
                  ? AppColors.highlightColor.withValues(alpha: 0.8)
                  : AppColors.textPrimary.withValues(alpha: 0.5),
              width: AppColors.borderThickness,
            ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: AppColors.highlightColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: Stack(
              children: [
                Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isPressed ? 0.3 : 0.7,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: AppColors.textPrimary,
                          size: 48,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'touchpad',
                          style: TextStyle(
                            fontFamily: 'pico',
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_fingerPosition != null)
                  Positioned(
                    left: _fingerPosition!.dx - 40,
                    top: _fingerPosition!.dy - 40,
                    child: AnimatedScale(
                      scale: _isPressed ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: _isPressed ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.highlightColor.withValues(
                              alpha: 0.25,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.highlightColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MouseScrollStrip extends StatefulWidget {
  const _MouseScrollStrip({required this.onScroll});

  final ValueChanged<double> onScroll;

  @override
  State<_MouseScrollStrip> createState() => _MouseScrollStripState();
}

class _MouseScrollStripState extends State<_MouseScrollStrip> {
  bool _isScrolling = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => setState(() => _isScrolling = true),
      onVerticalDragUpdate: (details) {
        final dragDelta = details.primaryDelta ?? 0;
        if (dragDelta.abs() < 1) {
          return;
        }
        widget.onScroll((-dragDelta / 32).clamp(-1.2, 1.2));
      },
      onVerticalDragEnd: (_) => setState(() => _isScrolling = false),
      onVerticalDragCancel: () => setState(() => _isScrolling = false),
      child: AnimatedScale(
        scale: _isScrolling ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _isScrolling
                ? AppColors.highlightColor.withValues(alpha: 0.12)
                : AppColors.backgroundColor.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _isScrolling
                  ? AppColors.highlightColor.withValues(alpha: 0.8)
                  : AppColors.textPrimary.withValues(alpha: 0.5),
              width: AppColors.borderThickness,
            ),
            boxShadow: _isScrolling
                ? [
                    BoxShadow(
                      color: AppColors.highlightColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isScrolling ? 0.4 : 1.0,
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
        ),
      ),
    );
  }
}
