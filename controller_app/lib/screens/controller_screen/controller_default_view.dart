import 'package:flutter/material.dart';

import '../../models/player_face.dart';
import '../../widgets/action_buttons.dart';
import '../../widgets/control_button.dart' hide ButtonStateCallback;
import '../../widgets/joystick.dart';
import 'controller_screen_types.dart';
import 'controller_screen_widgets.dart';

typedef ControllerButtonStateCallback = void Function(String id, String state);

class ControllerDefaultView extends StatelessWidget {
  const ControllerDefaultView({
    super.key,
    required this.dpadMode,
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

  final bool dpadMode;
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
          child: Align(
            alignment: Alignment.centerLeft,
            child: dpadMode
                ? _ControllerDpad(onButtonStateChanged: onButtonStateChanged)
                : Joystick(
                    size: 220,
                    onChanged: (x, y) => onStickChanged(Offset(x, y)),
                    onReleased: onStickRelease,
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

class _ControllerDpad extends StatelessWidget {
  const _ControllerDpad({required this.onButtonStateChanged});

  final ControllerButtonStateCallback onButtonStateChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 258,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _gridButton('up', 'UP'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _gridButton('left', 'LEFT'),
              _gridButton('right', 'RIGHT'),
            ],
          ),
          _gridButton('down', 'DOWN'),
        ],
      ),
    );
  }

  Widget _gridButton(String action, String label) {
    return ControlButton(
      label: label,
      onStateChange: (state) => onButtonStateChanged(action.toUpperCase(), state),
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
