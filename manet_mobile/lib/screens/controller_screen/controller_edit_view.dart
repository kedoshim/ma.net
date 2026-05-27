import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/controller_branding.dart';
import '../../models/player_face.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/control_button.dart' hide ButtonStateCallback;
import '../../widgets/action_buttons.dart';
import 'controller_screen_widgets.dart';

class ControllerEditView extends StatefulWidget {
  const ControllerEditView({
    super.key,
    required this.brandingMode,
    required this.tapHapticsEnabled,
    required this.onTapHapticsToggled,
    required this.editableButtons,
    required this.visibleButtons,
    required this.buttonOrder,
    required this.onSetButtonVisibility,
    required this.onButtonOrderChanged,
    required this.onGameButtonStateChanged,
    required this.onExit,
    required this.totalSlots,
    required this.playerIndex,
    required this.status,
    required this.playerFace,
    required this.centerPulseExpanded,
    required this.onPulseCycleEnd,
  });

  final ControllerBrandingMode brandingMode;
  final bool tapHapticsEnabled;
  final VoidCallback onTapHapticsToggled;
  final List<String> editableButtons;
  final Map<String, bool> visibleButtons;
  final List<String> buttonOrder;
  final void Function(String, bool) onSetButtonVisibility;
  final void Function(List<String>) onButtonOrderChanged;
  final ButtonStateCallback onGameButtonStateChanged;
  final VoidCallback onExit;
  final int totalSlots;
  final int? playerIndex;
  final String status;
  final PlayerFaceData playerFace;
  final bool centerPulseExpanded;
  final VoidCallback onPulseCycleEnd;

  @override
  State<ControllerEditView> createState() => _ControllerEditViewState();
}

class _ControllerEditViewState extends State<ControllerEditView>
    with TickerProviderStateMixin {
  bool _isDragging = false;
  bool _showTutorial = false;
  late AnimationController _tutorialController;

  @override
  void initState() {
    super.initState();
    _tutorialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _checkTutorial();
  }

  Future<void> _checkTutorial() async {
    final seen = await PreferencesService.instance.getHasSeenEditTutorial();
    if (!seen && mounted) {
      setState(() => _showTutorial = true);
      await PreferencesService.instance.setHasSeenEditTutorial(true);

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      await _tutorialController.forward();
      if (!mounted) return;

      setState(() => _showTutorial = false);
    }
  }

  @override
  void dispose() {
    _tutorialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableButtons = widget.editableButtons
        .where((key) => widget.visibleButtons[key] != true)
        .toList();

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: _AvailableButtonsPanel(
                brandingMode: widget.brandingMode,
                isDragging: _isDragging,
                buttons: availableButtons,
                tapHapticsEnabled: widget.tapHapticsEnabled,
                onButtonDropped: (buttonKey) =>
                    widget.onSetButtonVisibility(buttonKey, false),
                onDragStarted: () => setState(() => _isDragging = true),
                onDragEnded: () => setState(() => _isDragging = false),
              ),
            ),
            const SizedBox(width: 24),
            Column(
              children: [
                Expanded(
                  flex: 2,
                  child: ControllerModeHub(
                    icon: Icons.close_rounded,
                    title: 'editar controles',
                    onTap: widget.onExit,
                    totalSlots: widget.totalSlots,
                    selectedPlayerIndex: widget.playerIndex,
                    status: widget.status,
                    playerFace: widget.playerFace,
                    centerPulseExpanded: widget.centerPulseExpanded,
                    onPulseCycleEnd: widget.onPulseCycleEnd,
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
                        widget.tapHapticsEnabled
                            ? Icons.vibration_rounded
                            : Icons.mobile_off_rounded,
                        color: AppColors.textPrimary,
                      ),
                      onStateChange: (state) {
                        if (state == 'up') {
                          widget.onTapHapticsToggled();
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 3,
              child: DragTarget<String>(
                onWillAcceptWithDetails: (details) {
                  return availableButtons.contains(details.data);
                },
                onAcceptWithDetails: (details) {
                  widget.onSetButtonVisibility(details.data, true);
                },
                builder: (context, candidateData, rejectedData) {
                  final isTarget = candidateData.isNotEmpty;
                  return Container(
                    decoration: BoxDecoration(
                      color: isTarget
                          ? AppColors.dragTargetGreen.withValues(alpha: 0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: ActionButtons(
                      brandingMode: widget.brandingMode,
                      visibleButtons: widget.visibleButtons,
                      buttonOrder: widget.buttonOrder,
                      onButtonStateChanged: widget.onGameButtonStateChanged,
                      editMode: true,
                      tapHapticsEnabled: widget.tapHapticsEnabled,
                      onDragStarted: () => setState(() => _isDragging = true),
                      onDragEnded: () => setState(() => _isDragging = false),
                      onButtonOrderChanged: widget.onButtonOrderChanged,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (_showTutorial) _buildTutorialAnimation(),
      ],
    );
  }

  Widget _buildTutorialAnimation() {
    return AnimatedBuilder(
      animation: _tutorialController,
      builder: (context, child) {
        final t = _tutorialController.value;
        final lift = math.sin(t * math.pi);
        final scale = 1.0 + lift * 0.2;

        final screenWidth = MediaQuery.of(context).size.width;
        final startX = screenWidth * 0.2;
        final endX = screenWidth * 0.8;

        final xProgress = Curves.easeInOutCubic.transform(
          ((t - 0.2) / 0.6).clamp(0.0, 1.0),
        );
        final x = startX + (endX - startX) * xProgress;

        final screenHeight = MediaQuery.of(context).size.height;
        final startY = screenHeight * 0.6;
        final endY = screenHeight * 0.4;
        final arch = math.sin(xProgress * math.pi) * 80;
        final y = startY + (endY - startY) * xProgress - arch - (lift * 20);

        return Positioned(
          left: x - 48,
          top: y - 48,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: t < 0.1 ? t / 0.1 : (t > 0.9 ? (1.0 - t) / 0.1 : 1.0),
              child: Container(
                width: 96,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.highlightColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.textPrimary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(
                        alpha: 0.3 * lift,
                      ),
                      blurRadius: 16 * lift,
                      offset: Offset(0, 12 * lift),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.touch_app_rounded,
                    color: AppColors.textPrimary,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AvailableButtonsPanel extends StatelessWidget {
  const _AvailableButtonsPanel({
    required this.brandingMode,
    required this.isDragging,
    required this.buttons,
    required this.onButtonDropped,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.tapHapticsEnabled,
  });

  final ControllerBrandingMode brandingMode;
  final bool isDragging;
  final List<String> buttons;
  final ValueChanged<String> onButtonDropped;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;
  final bool tapHapticsEnabled;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        return !buttons.contains(details.data);
      },
      onAcceptWithDetails: (details) {
        onButtonDropped(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isTarget
                ? AppColors.highlightColor.withValues(alpha: 0.5)
                : AppColors.backgroundColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isTarget
                  ? AppColors.highlightColor
                  : AppColors.textPrimary,
              width: AppColors.borderThickness,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'unused buttons',
                style: TextStyle(
                  fontFamily: 'momo',
                  fontSize: 22,
                  color: AppColors.textPrimary.withValues(
                    alpha: isTarget ? 1.0 : 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: buttons.map((buttonKey) {
                      final presentation = ControllerBranding.presentationFor(
                        buttonKey,
                        brandingMode,
                      );
                      return DraggableEditButton(
                        btnId: buttonKey,
                        label: presentation.shortLabel,
                        labelWidget: ControllerButtonBrand(
                          presentation: presentation,
                          size: 24,
                        ),
                        onDragStarted: onDragStarted,
                        onDragEnded: onDragEnded,
                        tapHapticsEnabled: tapHapticsEnabled,
                        baseColor: AppColors.backgroundColor.withValues(
                          alpha: 0.2,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
