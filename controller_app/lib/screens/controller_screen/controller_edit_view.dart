import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/player_face.dart';
import '../../theme/app_colors.dart';
import '../../widgets/control_button.dart' hide ButtonStateCallback;
import '../../widgets/action_buttons.dart';
import 'controller_screen_widgets.dart';

class ControllerEditView extends StatelessWidget {
  const ControllerEditView({
    super.key,
    required this.tapHapticsEnabled,
    required this.onTapHapticsToggled,
    required this.editableButtons,
    required this.visibleButtons,
    required this.onButtonVisibilityToggled,
    required this.onGameButtonStateChanged,
    required this.onExit,
    required this.totalSlots,
    required this.playerIndex,
    required this.status,
    required this.playerFace,
    required this.centerPulseExpanded,
    required this.onPulseCycleEnd,
  });

  final bool tapHapticsEnabled;
  final VoidCallback onTapHapticsToggled;
  final List<String> editableButtons;
  final Map<String, bool> visibleButtons;
  final ValueChanged<String> onButtonVisibilityToggled;
  final ButtonStateCallback onGameButtonStateChanged;
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
          flex: 3,
          child: _EditControlsPanel(
            tapHapticsEnabled: tapHapticsEnabled,
            onTapHapticsToggled: onTapHapticsToggled,
            editableButtons: editableButtons,
            visibleButtons: visibleButtons,
            onButtonVisibilityToggled: onButtonVisibilityToggled,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            Expanded(
              flex: 2,
              child: ControllerModeHub(
                icon: Icons.tune_rounded,
                title: 'edit mode',
                onTap: onExit,
                totalSlots: totalSlots,
                selectedPlayerIndex: playerIndex,
                status: status,
                playerFace: playerFace,
                centerPulseExpanded: centerPulseExpanded,
                onPulseCycleEnd: onPulseCycleEnd,
              ),
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: ControlButton(
                  label: '',
                  width: 84,
                  height: 58,
                  icon: Icon(
                    tapHapticsEnabled ? Icons.vibration_rounded : Icons.mobile_off_rounded,
                    color: AppColors.textPrimary,
                  ),
                  onStateChange: (state) {
                    if (state == 'up') {
                      onTapHapticsToggled();
                    }
                  },
                ),
              ),
            ],
            
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: ActionButtons(
            visibleButtons: visibleButtons,
            onButtonStateChanged: onGameButtonStateChanged,
            editMode: true,
          ),
        ),
      ],
    );
  }
}

class _EditControlsPanel extends StatelessWidget {
  const _EditControlsPanel({
    required this.tapHapticsEnabled,
    required this.onTapHapticsToggled,
    required this.editableButtons,
    required this.visibleButtons,
    required this.onButtonVisibilityToggled,
  });

  final bool tapHapticsEnabled;
  final VoidCallback onTapHapticsToggled;
  final List<String> editableButtons;
  final Map<String, bool> visibleButtons;
  final ValueChanged<String> onButtonVisibilityToggled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.textPrimary,
          width: AppColors.borderThickness,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'edit controls',
            style: TextStyle(
              fontFamily: 'pico',
              fontSize: 22,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...editableButtons.map(
                    (buttonKey) => _EditToggleTile(
                      label: buttonKey.replaceFirst('btn', ''),
                      visible: visibleButtons[buttonKey] ?? true,
                      onTap: () => onButtonVisibilityToggled(buttonKey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditToggleTile extends StatelessWidget {
  const _EditToggleTile({
    required this.label,
    required this.visible,
    required this.onTap,
  });

  final String label;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: visible
              ? AppColors.highlightColor.withValues(alpha: 0.34)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.textPrimary,
            width: visible ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'pico',
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              visible ? 'on' : 'off',
              style: TextStyle(
                fontFamily: 'pico',
                fontSize: 11,
                color: AppColors.textPrimary.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
