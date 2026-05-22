import 'package:flutter/material.dart';

import '../../models/player_face.dart';
import '../../theme/app_colors.dart';
import '../../widgets/action_buttons.dart';
import '../../widgets/control_button.dart' hide ButtonStateCallback;
import '../../widgets/joystick.dart';
import '../../services/preferences_service.dart';
import 'controller_screen_types.dart';
import 'controller_screen_widgets.dart';

typedef ControllerButtonStateCallback = void Function(String id, String state);

class ControllerDefaultView extends StatelessWidget {
  const ControllerDefaultView({
    super.key,
    required this.movementMode,
    required this.onStickChanged,
    required this.onStickRelease,
    required this.onButtonStateChanged,
    required this.onOpenOptions,
    required this.onRetryConnection,
    required this.onOpenQrScanner,
    required this.connectionState,
    required this.status,
    required this.playerFace,
    required this.playerColor,
    required this.playerIndex,
    required this.totalSlots,
    required this.visibleButtons,
  });

  final MovementMode movementMode;
  final ValueChanged<Offset> onStickChanged;
  final VoidCallback onStickRelease;
  final ControllerButtonStateCallback onButtonStateChanged;
  final VoidCallback onOpenOptions;
  final VoidCallback onRetryConnection;
  final VoidCallback? onOpenQrScanner;
  final ControllerConnectionState connectionState;
  final String status;
  final PlayerFaceData playerFace;
  final Color? playerColor;
  final int? playerIndex;
  final int totalSlots;
  final Map<String, bool> visibleButtons;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: movementMode == MovementMode.dpad
              ? _ControllerDpad(onButtonStateChanged: onButtonStateChanged)
              : Padding(
                  padding: const EdgeInsets.only(left: 24.0, bottom: 8.0),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: movementMode == MovementMode.adaptiveJoystick
                        ? AdaptiveJoystick(
                            onChanged: (x, y) => onStickChanged(Offset(x, y)),
                            onReleased: onStickRelease,
                          )
                        : Joystick(
                            size: 220,
                            onChanged: (x, y) => onStickChanged(Offset(x, y)),
                            onReleased: onStickRelease,
                          ),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const Text(
                'ma•net',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                  fontFamily: 'pico',
                ),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ControllerCenterStatus(
                          connectionState: connectionState,
                          status: status,
                          playerFace: playerFace,
                          playerColor: playerColor,
                          onRetry: onRetryConnection,
                          onOpenQrScanner: onOpenQrScanner,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ControllerPlayerIndicator(
                      totalSlots: totalSlots,
                      selectedPlayerIndex: playerIndex,
                      status: status,
                      playerFace: playerFace,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              IconButton(
                icon: const Icon(Icons.settings, size: 32),
                onPressed: onOpenOptions,
                tooltip: 'Options',
              ),
              const SizedBox(height: 18),
              _CenterAction(onButtonStateChanged: onButtonStateChanged),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: ActionButtons(
            visibleButtons: visibleButtons,
            onButtonStateChanged: onButtonStateChanged,
            editMode: false,
          ),
        ),
      ],
    );
  }
}

class _ControllerDpad extends StatefulWidget {
  const _ControllerDpad({required this.onButtonStateChanged});

  final ControllerButtonStateCallback onButtonStateChanged;

  @override
  State<_ControllerDpad> createState() => _ControllerDpadState();
}

class _ControllerDpadState extends State<_ControllerDpad> {
  String? _activeDirection;

  void _updateDirection(Offset localPosition, Size size) {
    // The D-pad covers the whole left area, but visually is anchored bottom-left.
    // With 24.0 left padding and 8.0 bottom padding, the center of the 240x258 D-pad is:
    // x = 24.0 + (240 / 2) = 144.0
    // y = size.height - 8.0 - (258 / 2) = size.height - 137.0
    final center = Offset(144.0, size.height - 137.0);
    final delta = localPosition - center;

    // Generous extended bound check allowing inputs well outside the visual area
    if (localPosition.dx < -50 ||
        localPosition.dx > size.width + 50 ||
        localPosition.dy < -50 ||
        localPosition.dy > size.height + 50) {
      _releaseDirection();
      return;
    }

    // Deadzone in the center
    if (delta.distance < 25) {
      _releaseDirection();
      return;
    }

    String newDirection;
    if (delta.dx.abs() > delta.dy.abs()) {
      newDirection = delta.dx > 0 ? 'RIGHT' : 'LEFT';
    } else {
      newDirection = delta.dy > 0 ? 'DOWN' : 'UP';
    }

    if (_activeDirection != newDirection) {
      if (_activeDirection != null) {
        widget.onButtonStateChanged(_activeDirection!, 'up');
      }
      _activeDirection = newDirection;
      widget.onButtonStateChanged(_activeDirection!, 'down');
      setState(() {});
    }
  }

  void _releaseDirection() {
    if (_activeDirection != null) {
      widget.onButtonStateChanged(_activeDirection!, 'up');
      setState(() {
        _activeDirection = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        _updateDirection(details.localPosition, box.size);
      },
      onPanUpdate: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        _updateDirection(details.localPosition, box.size);
      },
      onPanEnd: (_) => _releaseDirection(),
      onPanCancel: () => _releaseDirection(),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 24.0, bottom: 8.0),
          child: SizedBox(
            width: 240,
            height: 258,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DPadButton(label: '', isActive: _activeDirection == 'UP'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _DPadButton(
                      label: '',
                      isActive: _activeDirection == 'LEFT',
                    ),
                    _DPadButton(
                      label: '',
                      isActive: _activeDirection == 'RIGHT',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _DPadButton(label: '', isActive: _activeDirection == 'DOWN'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DPadButton extends StatelessWidget {
  final String label;
  final bool isActive;

  const _DPadButton({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final background = isActive
        ? AppColors.highlightColor
        : AppColors.backgroundColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: 76,
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary,
          width: AppColors.borderThickness,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          fontFamily: 'pico',
        ),
      ),
    );
  }
}

class _CenterAction extends StatelessWidget {
  const _CenterAction({required this.onButtonStateChanged});

  final ControllerButtonStateCallback onButtonStateChanged;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: ControlButton(
              label: '',
              onStateChange: (state) => onButtonStateChanged('SELECT', state),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            height: 56,
            child: ControlButton(
              label: '',
              onStateChange: (state) => onButtonStateChanged('START', state),
            ),
          ),
        ],
      ),
    );
  }
}
