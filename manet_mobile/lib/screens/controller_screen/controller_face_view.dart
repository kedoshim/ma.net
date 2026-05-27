import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/player_face.dart';
import '../../theme/app_colors.dart';
import '../../widgets/player_face_indicator.dart';
import 'controller_screen_widgets.dart';

class ControllerFaceView extends StatelessWidget {
  const ControllerFaceView({
    super.key,
    required this.playerFace,
    required this.faceController,
    required this.faceFocusNode,
    required this.onFaceChanged,
    required this.onColorSelected,
    required this.onRotationSelected,
    required this.onPresetSelected,
    required this.onExit,
    required this.totalSlots,
    required this.playerIndex,
    required this.status,
    required this.centerPulseExpanded,
    required this.onPulseCycleEnd,
  });

  final PlayerFaceData playerFace;
  final TextEditingController faceController;
  final FocusNode faceFocusNode;
  final ValueChanged<String> onFaceChanged;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<PlayerFaceRotation> onRotationSelected;
  final ValueChanged<PlayerFacePreset> onPresetSelected;
  final VoidCallback onExit;
  final int totalSlots;
  final int? playerIndex;
  final String status;
  final bool centerPulseExpanded;
  final VoidCallback onPulseCycleEnd;

  @override
  Widget build(BuildContext context) {
    final isTyping = faceFocusNode.hasFocus;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => faceFocusNode.requestFocus(),
                child: PlayerFaceIndicator(
                  face: playerFace,
                  size: 160,
                  roundedSquare: true,
                  borderColor: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (!isTyping) ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ControllerModeHub(
              icon: Icons.close_rounded,
              title: 'rostinho',
              onTap: onExit,
              totalSlots: totalSlots,
              selectedPlayerIndex: playerIndex,
              status: status,
              playerFace: playerFace,
              centerPulseExpanded: centerPulseExpanded,
              onPulseCycleEnd: onPulseCycleEnd,
            ),
          ),
        ],
        const SizedBox(width: 12),
        Expanded(
          flex: isTyping ? 5 : 4,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.textPrimary,
                width: AppColors.borderThickness,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isTyping) ...[
                    const Text(
                      'cores',
                      style: TextStyle(fontFamily: 'momo', fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: playerFacePalette
                          .map(
                            (color) => _ColorSwatch(
                              color: color,
                              isSelected:
                                  color.toARGB32() ==
                                  playerFace.color.toARGB32(),
                              onTap: () => onColorSelected(color),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isTyping) ...[
                            const Text(
                              'rosto',
                              style: TextStyle(
                                fontFamily: 'momo',
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Container(
                            constraints: BoxConstraints(
                              minWidth: 120,
                              maxWidth: isTyping ? 320 : 200,
                            ),
                            child: TextField(
                              focusNode: faceFocusNode,
                              controller: faceController,
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(
                                  RegExp(r'[\r\n\t]'),
                                ),
                              ],
                              style: TextStyle(
                                fontFamily: 'monomaniac',
                                fontSize: isTyping ? 48 : 22,
                                color: AppColors.textPrimary,
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => faceFocusNode.unfocus(),
                              onTapOutside: (_) => faceFocusNode.unfocus(),
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isTyping ? 20 : 12,
                                  vertical: isTyping ? 24 : 12,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    isTyping ? 20 : 14,
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.textPrimary,
                                    width: isTyping ? 3 : 2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    isTyping ? 20 : 14,
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.highlightColor,
                                    width: isTyping ? 4 : 2,
                                  ),
                                ),
                              ),
                              onChanged: onFaceChanged,
                            ),
                          ),
                        ],
                      ),
                      if (!isTyping)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'rotacao',
                              style: TextStyle(
                                fontFamily: 'momo',
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: PlayerFaceRotation.values
                                  .map(
                                    (rotation) => _RotationButton(
                                      face: playerFace,
                                      rotation: rotation,
                                      isSelected:
                                          playerFace.rotation == rotation,
                                      onTap: () => onRotationSelected(rotation),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (!isTyping) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'presets',
                      style: TextStyle(fontFamily: 'momo', fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: playerFacePresets
                          .map(
                            (preset) => _PresetChip(
                              previewFace: playerFace.applyPreset(preset),
                              preset: preset,
                              isSelected: playerFace.presetId == preset.id,
                              onTap: () => onPresetSelected(preset),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.textPrimary,
            width: isSelected ? 3 : 1.5,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, size: 18, color: Colors.black87)
            : null,
      ),
    );
  }
}

class _RotationButton extends StatelessWidget {
  const _RotationButton({
    required this.face,
    required this.rotation,
    required this.isSelected,
    required this.onTap,
  });

  final PlayerFaceData face;
  final PlayerFaceRotation rotation;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.highlightColor.withValues(alpha: 0.35)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.textPrimary.withValues(alpha: 0.25),
            width: 2,
          ),
        ),
        child: Center(
          child: PlayerFaceIndicator(
            face: face.copyWith(rotation: rotation),
            size: 28,
            roundedSquare: true,
            borderColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.previewFace,
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  final PlayerFaceData previewFace;
  final PlayerFacePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? preset.color.withValues(alpha: 0.35)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.textPrimary.withValues(alpha: 0.25),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerFaceIndicator(
              face: previewFace,
              size: 24,
              roundedSquare: true,
              borderColor: Colors.transparent,
            ),
            const SizedBox(width: 8),
            Text(
              preset.label,
              style: const TextStyle(
                fontFamily: 'momo',
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
