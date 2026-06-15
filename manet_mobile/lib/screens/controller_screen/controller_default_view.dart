import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/controller_branding.dart';
import '../../models/player_face.dart';
import '../../widgets/player_face_indicator.dart';
import '../../theme/app_colors.dart';
import '../../widgets/action_buttons.dart';
import '../../widgets/control_button.dart' hide ButtonStateCallback;
import '../../services/haptics_manager.dart';
import '../../widgets/joystick.dart';
import '../../services/preferences_service.dart';
import '../../l10n/app_localizations.dart';
import 'controller_screen_types.dart';
import 'controller_screen_widgets.dart';
import '../../widgets/right_stick_controls.dart';

typedef ControllerButtonStateCallback = void Function(String id, String state);

class ControllerDefaultView extends StatefulWidget {
  const ControllerDefaultView({
    super.key,
    required this.brandingMode,
    required this.movementMode,
    required this.onMovementModeChanged,
    required this.onStickChanged,
    required this.onStickRelease,
    required this.onButtonStateChanged,
    required this.onOpenOptions,
    required this.onOpenFaceEditor,
    required this.onOpenEditControls,
    required this.onRetryConnection,
    required this.onOpenQrScanner,
    required this.connectionState,
    required this.status,
    required this.playerFace,
    required this.playerColor,
    required this.playerIndex,
    required this.totalSlots,
    required this.visibleButtons,
    required this.buttonOrder,
    required this.hasVacantSlot,
    required this.onJoinGame,
    required this.playerName,
    required this.onNameChanged,
    required this.onRequestRandomName,
    this.onRightStickChanged,
    this.onRightStickRelease,
    required this.buttonSizes,
    required this.rightLayoutMode,
    required this.leftStickSensitivity,
    required this.rightStickSensitivity,
    required this.swipeAccelerationIntensity,
    required this.rightStickAntiDeadzone,
    required this.rightStickResponseCurve,
    required this.isPanelExpanded,
    required this.panelMode,
    required this.onPanelExpandedChanged,
    required this.onPanelModeChanged,
    required this.editableButtons,
    required this.onSetButtonVisibility,
    required this.onButtonOrderChanged,
    required this.onButtonSizesChanged,
    required this.onRightLayoutModeChanged,
    required this.tapHapticsEnabled,
    required this.onTapHapticsToggled,
    this.pulseOptionsButton = false,
    this.onResetOptionsPulse,
  });

  final bool isPanelExpanded;
  final ControllerPanelMode panelMode;
  final ValueChanged<bool> onPanelExpandedChanged;
  final ValueChanged<ControllerPanelMode> onPanelModeChanged;
  final List<String> editableButtons;
  final void Function(String, bool) onSetButtonVisibility;
  final void Function(List<String>) onButtonOrderChanged;
  final void Function(Map<String, int>) onButtonSizesChanged;
  final ValueChanged<String> onRightLayoutModeChanged;
  final bool tapHapticsEnabled;
  final VoidCallback onTapHapticsToggled;
  final bool pulseOptionsButton;
  final VoidCallback? onResetOptionsPulse;

  final double leftStickSensitivity;
  final double rightStickSensitivity;
  final double swipeAccelerationIntensity;
  final double rightStickAntiDeadzone;
  final double rightStickResponseCurve;

  final String? playerName;
  final ValueChanged<String> onNameChanged;
  final Future<String> Function() onRequestRandomName;

  final ControllerBrandingMode brandingMode;
  final MovementMode movementMode;
  final ValueChanged<MovementMode> onMovementModeChanged;
  final ValueChanged<Offset> onStickChanged;
  final VoidCallback onStickRelease;
  final ControllerButtonStateCallback onButtonStateChanged;
  final VoidCallback onOpenOptions;
  final VoidCallback onOpenFaceEditor;
  final VoidCallback onOpenEditControls;
  final VoidCallback onRetryConnection;
  final VoidCallback? onOpenQrScanner;
  final ControllerConnectionState connectionState;
  final String status;
  final PlayerFaceData playerFace;
  final Color? playerColor;
  final int? playerIndex;
  final int totalSlots;
  final Map<String, bool> visibleButtons;
  final List<String> buttonOrder;
  final bool hasVacantSlot;
  final VoidCallback? onJoinGame;
  final ValueChanged<Offset>? onRightStickChanged;
  final VoidCallback? onRightStickRelease;
  final Map<String, int> buttonSizes;
  final String rightLayoutMode;

  @override
  State<ControllerDefaultView> createState() => _ControllerDefaultViewState();
}

class _ControllerDefaultViewState extends State<ControllerDefaultView>
    with TickerProviderStateMixin {
  bool _isDragging = false;
  bool _showTutorial = false;
  late AnimationController _tutorialController;
  bool _showDpadInSecondary = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseScaleAnimation;

  @override
  void initState() {
    super.initState();
    _tutorialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseScaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.25).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_pulseController);
    _loadSecondaryMovementPreference();
  }

  Future<void> _loadSecondaryMovementPreference() async {
    final showDpad = await PreferencesService.instance.getShowDpadInSecondary();
    if (mounted) {
      setState(() {
        _showDpadInSecondary = showDpad;
      });
    }
  }

  Future<void> _toggleSecondaryMovement() async {
    setState(() {
      _showDpadInSecondary = !_showDpadInSecondary;
    });
    await PreferencesService.instance.setShowDpadInSecondary(_showDpadInSecondary);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tutorialController.dispose();
    super.dispose();
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
  void didUpdateWidget(covariant ControllerDefaultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.isPanelExpanded && !oldWidget.isPanelExpanded && widget.panelMode == ControllerPanelMode.edit) ||
        (widget.isPanelExpanded && widget.panelMode == ControllerPanelMode.edit && oldWidget.panelMode != ControllerPanelMode.edit)) {
      _checkTutorial();
    }
    if (widget.pulseOptionsButton && !oldWidget.pulseOptionsButton) {
      _triggerOptionsPulse();
    }
  }

  void _triggerOptionsPulse() {
    _pulseController.repeat(reverse: true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _pulseController.stop();
        _pulseController.reset();
        widget.onResetOptionsPulse?.call();
      }
    });
  }

  void _toggleMovementMode() {
    final nextIndex =
        (widget.movementMode.index + 1) % MovementMode.values.length;
    final nextMode = MovementMode.values[nextIndex];
    widget.onMovementModeChanged(nextMode);
  }

  IconData _getNextModeIcon(MovementMode mode) {
    switch (mode) {
      case MovementMode.dpad:
        return Icons.control_camera_rounded;
      case MovementMode.fixedJoystick:
        return Icons.touch_app_rounded;
      case MovementMode.floatingJoystick:
        return Icons.gamepad_outlined;
    }
  }

  String _getNextModeLabel(BuildContext context, MovementMode mode) {
    switch (mode) {
      case MovementMode.dpad:
        return context.l10n.joystick.changeToFixed;
      case MovementMode.fixedJoystick:
        return context.l10n.joystick.changeToFloating;
      case MovementMode.floatingJoystick:
        return context.l10n.joystick.changeToDpad;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // flex layout ratio: 12 : 7 : 12 = 31 total flex.
        final leftCenterWidth = totalWidth * (19.0 / 31.0);
        final rightWidth = totalWidth * (12.0 / 31.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Layer 1: Left + Center Columns of Gameplay
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: leftCenterWidth,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left side (flex: 12)
                    Expanded(
                      flex: 12,
                      child: widget.movementMode == MovementMode.dpad
                          ? _ControllerDpad(
                              onButtonStateChanged: widget.onButtonStateChanged,
                            )
                          : widget.movementMode == MovementMode.floatingJoystick
                          ? AdaptiveJoystick(
                              onChanged: (x, y) => widget.onStickChanged(Offset(x, y)),
                              onReleased: widget.onStickRelease,
                              sensitivity: widget.leftStickSensitivity,
                            )
                          : Joystick(
                              size: 220,
                              onChanged: (x, y) => widget.onStickChanged(Offset(x, y)),
                              onReleased: widget.onStickRelease,
                              sensitivity: widget.leftStickSensitivity,
                            ),
                    ),
                    // Center (flex: 7)
                    Expanded(
                      flex: 7,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 0),
                                  child: Container(
                                    alignment: Alignment.topCenter,
                                    child: SizedBox(
                                      width: 32,
                                      height: 48,
                                      child: Material(
                                        color: AppColors.backgroundColor.withValues(
                                          alpha: 0.05,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: const BorderSide(
                                            color: Colors.transparent,
                                            width: AppColors.borderThickness,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            _getNextModeIcon(widget.movementMode),
                                            size: 18,
                                          ),
                                          splashRadius: 10,
                                          onPressed: _toggleMovementMode,
                                          tooltip: _getNextModeLabel(context, widget.movementMode),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'ma•net',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.normal,
                                        fontFamily: 'momo',
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    InkWell(
                                      onTap: widget.onOpenFaceEditor,
                                      borderRadius: BorderRadius.circular(24),
                                      child: PlayerFaceIndicator(
                                        face: widget.playerFace,
                                        size: 64,
                                        roundedSquare: true,
                                        borderColor: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _PlayerNameWidget(
                                      name: widget.playerName,
                                      onNameChanged: widget.onNameChanged,
                                      onRequestRandomName: widget.onRequestRandomName,
                                      playerFace: widget.playerFace,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Padding(
                                  padding: const EdgeInsets.only(top: 0, right: 4),
                                  child: Container(
                                    alignment: Alignment.topCenter,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 32,
                                          height: 48,
                                          child: Material(
                                            color: AppColors.backgroundColor.withValues(
                                              alpha: 0.05,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              side: const BorderSide(
                                                color: Colors.transparent,
                                                width: AppColors.borderThickness,
                                              ),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.arrow_left_rounded, size: 20),
                                              splashRadius: 10,
                                              onPressed: () {
                                                widget.onPanelExpandedChanged(true);
                                                widget.onPanelModeChanged(ControllerPanelMode.use);
                                              },
                                              tooltip: context.l10n.options.secondaryControls,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ControllerCenterStatus(
                                  connectionState: widget.connectionState,
                                  status: widget.status,
                                  playerFace: widget.playerFace,
                                  playerColor: null,
                                ),
                                const SizedBox(height: 8),
                                if (widget.connectionState ==
                                    ControllerConnectionState.disconnected)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: widget.onRetryConnection,
                                        child: const Icon(
                                          Icons.refresh,
                                          color: AppColors.textPrimary,
                                          size: 24,
                                        ),
                                      ),
                                      if (!kIsWeb && widget.onOpenQrScanner != null) ...[
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: widget.onOpenQrScanner,
                                          child: const Icon(
                                            Icons.qr_code_scanner,
                                            color: AppColors.textPrimary,
                                            size: 24,
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                else
                                  ControllerPlayerIndicator(
                                    totalSlots: widget.totalSlots,
                                    selectedPlayerIndex: widget.playerIndex,
                                    isConnected: widget.connectionState == ControllerConnectionState.connected,
                                    playerFace: widget.playerFace,
                                    hasVacantSlot: widget.hasVacantSlot,
                                    onJoinGame: widget.onJoinGame,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          ScaleTransition(
                            scale: _pulseScaleAnimation,
                            child: IconButton(
                              icon: const Icon(Icons.more_horiz, size: 32),
                              onPressed: widget.onOpenOptions,
                              tooltip: context.l10n.options.title,
                            ),
                          ),
                          _CenterAction(
                            onButtonStateChanged: widget.onButtonStateChanged,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Layer 2: Expanded Sliding Panel overlaying Left + Center
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: leftCenterWidth,
              child: ClipRect(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: widget.isPanelExpanded ? 0.0 : 1.0,
                    end: widget.isPanelExpanded ? 0.0 : 1.0,
                  ),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  builder: (context, slideProgress, child) {
                    final xOffset = slideProgress * leftCenterWidth;
                    return Transform.translate(
                      offset: Offset(xOffset, 0),
                      child: child,
                    );
                  },
                  child: _buildExpandedPanel(leftCenterWidth),
                ),
              ),
            ),

            // Layer 3: Right Column (Action Buttons / Drag target)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: rightWidth,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _buildRightSideContent(),
              ),
            ),

            if (_showTutorial) _buildTutorialAnimation(),
          ],
        );
      },
    );
  }

  Widget _buildRightSideContent() {
    if (widget.panelMode == ControllerPanelMode.edit && widget.isPanelExpanded) {
      final availableButtons = widget.editableButtons
          .where((key) => widget.visibleButtons[key] != true)
          .toList();

      const rightStickControls = [
        'RS_BUTTON',
        'RS_FIXED',
        'RS_SWIPE',
      ];

      final availableRightStick = rightStickControls
          .where((key) => widget.visibleButtons[key] != true)
          .toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textPrimary,
                width: AppColors.borderThickness / 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLayoutModeSegment('columns', context.l10n.editControls.columnsMode),
                const SizedBox(width: 4),
                _buildLayoutModeSegment('rows', context.l10n.editControls.rowsMode),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<String>(
              onWillAcceptWithDetails: (details) {
                return availableButtons.contains(details.data) ||
                    availableRightStick.contains(details.data);
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
                    onButtonStateChanged: widget.onButtonStateChanged,
                    editMode: true,
                    tapHapticsEnabled: widget.tapHapticsEnabled,
                    onDragStarted: () => setState(() => _isDragging = true),
                    onDragEnded: () => setState(() => _isDragging = false),
                    onButtonOrderChanged: widget.onButtonOrderChanged,
                    buttonSizes: widget.buttonSizes,
                    onButtonSizesChanged: widget.onButtonSizesChanged,
                    rightLayoutMode: widget.rightLayoutMode,
                  ),
                );
              },
            ),
          ),
        ],
      );
    } else {
      return ActionButtons(
        brandingMode: widget.brandingMode,
        visibleButtons: widget.visibleButtons,
        buttonOrder: widget.buttonOrder,
        onButtonStateChanged: widget.onButtonStateChanged,
        editMode: false,
        onRightStickChanged: widget.onRightStickChanged,
        onRightStickRelease: widget.onRightStickRelease,
        buttonSizes: widget.buttonSizes,
        rightLayoutMode: widget.rightLayoutMode,
        rightStickSensitivity: widget.rightStickSensitivity,
        swipeAccelerationIntensity: widget.swipeAccelerationIntensity,
        rightStickAntiDeadzone: widget.rightStickAntiDeadzone,
        rightStickResponseCurve: widget.rightStickResponseCurve,
      );
    }
  }

  Widget _buildLayoutModeSegment(String mode, String label) {
    final isSelected = widget.rightLayoutMode == mode;
    return GestureDetector(
      onTap: () {
        if (widget.tapHapticsEnabled) {
          HapticsManager.instance.softTap();
        }
        widget.onRightLayoutModeChanged(mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.highlightColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.textPrimary : Colors.transparent,
            width: isSelected ? AppColors.borderThickness / 2 : 0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'momo',
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isSelected ? AppColors.textPrimary : AppColors.textPrimary.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedPanel(double width) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.screenBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textPrimary,
          width: AppColors.borderThickness,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 12,
            child: widget.panelMode == ControllerPanelMode.use
                ? _buildSecondaryUseLeftSection()
                : _buildSecondaryEditLeftSection(),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 7,
            child: _buildSecondaryCenterSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryUseLeftSection() {
    final secondaryButtons = <String>[];
    for (final btnId in widget.buttonOrder) {
      if (widget.visibleButtons[btnId] == false) {
        if (btnId == 'RS_BUTTON' || btnId == 'RS_FIXED' || btnId == 'RS_SWIPE') {
          continue;
        }
        secondaryButtons.add(btnId);
      }
    }

    final bool hasRightStickInMain = widget.visibleButtons['RS_FIXED'] == true ||
        widget.visibleButtons['RS_BUTTON'] == true ||
        widget.visibleButtons['RS_SWIPE'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Section: Secondary Buttons
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textPrimary,
                width: AppColors.borderThickness / 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.options.secondaryButtonsTitle,
                  style: const TextStyle(
                    fontFamily: 'momo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Align(
                      alignment: Alignment.center,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: secondaryButtons.map((btnId) {
                          final btnConfig = getButtonConfig(btnId);
                          final presentation = ControllerBranding.presentationFor(
                            btnConfig.xinput,
                            widget.brandingMode,
                          );
                          return SizedBox(
                            width: 64,
                            height: 64,
                            child: GameButton(
                              label: presentation.shortLabel,
                              labelWidget: ControllerButtonBrand(presentation: presentation, size: 28),
                              onStateChange: (state) =>
                                  widget.onButtonStateChanged(btnConfig.xinput, state),
                              tapHapticsEnabled: true,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Bottom Section: Movement + Camera
        Expanded(
          flex: 6,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bottom Left: Movement
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.textPrimary,
                      width: AppColors.borderThickness / 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.options.movementTitle,
                            style: const TextStyle(
                              fontFamily: 'momo',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: _toggleSecondaryMovement,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.textPrimary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.textPrimary.withValues(alpha: 0.15),
                                  width: AppColors.borderThickness / 2,
                                ),
                              ),
                              child: const Text(
                                '↔',
                                style: TextStyle(
                                  fontFamily: 'momo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (!_showDpadInSecondary)
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Joystick(
                            size: 56,
                            onChanged: (x, y) => widget.onStickChanged(Offset(x, y)),
                            onReleased: widget.onStickRelease,
                            sensitivity: widget.leftStickSensitivity,
                            isMini: true,
                          ),
                        )
                      else
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: 240,
                              height: 258,
                              child: _ControllerDpad(
                                onButtonStateChanged: widget.onButtonStateChanged,
                                isMini: true,
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              if (!hasRightStickInMain) ...[
                const SizedBox(width: 12),
                // Bottom Right: Right Stick
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.textPrimary,
                        width: AppColors.borderThickness / 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            context.l10n.options.rightStickTitle,
                            style: const TextStyle(
                              fontFamily: 'momo',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 68,
                          height: 68,
                          child: FixedRightStick(
                            output: RightStickOutput(
                              config: RightStickConfig(
                                sensitivity: widget.rightStickSensitivity,
                                antiDeadzone: widget.rightStickAntiDeadzone,
                                responseCurve: widget.rightStickResponseCurve,
                              ),
                              onSendValue: (x, y) => widget.onRightStickChanged?.call(Offset(x, y)),
                              onReleased: () => widget.onRightStickRelease?.call(),
                            ),
                            tapHapticsEnabled: true,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryEditLeftSection() {
    final availableButtons = widget.editableButtons
        .where((key) => widget.visibleButtons[key] != true)
        .toList();

    const rightStickControls = [
      'RS_BUTTON',
      'RS_FIXED',
      'RS_SWIPE',
    ];

    final availableRightStick = rightStickControls
        .where((key) => widget.visibleButtons[key] != true)
        .toList();

    return _AvailableButtonsPanel(
      brandingMode: widget.brandingMode,
      isDragging: _isDragging,
      buttons: availableButtons,
      rightStickControls: availableRightStick,
      tapHapticsEnabled: widget.tapHapticsEnabled,
      onButtonDropped: (buttonKey) =>
          widget.onSetButtonVisibility(buttonKey, false),
      onDragStarted: () => setState(() => _isDragging = true),
      onDragEnded: () => setState(() => _isDragging = false),
    );
  }

  Widget _buildSecondaryCenterSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildExpandedHeader(),
        InkWell(
          onTap: () {
            widget.onPanelExpandedChanged(false);
          },
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
            child: Icon(
              widget.panelMode == ControllerPanelMode.edit
                  ? Icons.close_rounded
                  : Icons.chevron_right_rounded,
              color: AppColors.textPrimary,
              size: 36,
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 180),
          child: ControllerPlayerIndicator(
            totalSlots: widget.totalSlots,
            selectedPlayerIndex: widget.playerIndex,
            isConnected: widget.connectionState == ControllerConnectionState.connected,
            playerFace: widget.playerFace,
          ),
        ),
        if (widget.panelMode == ControllerPanelMode.edit && !kIsWeb)
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
    );
  }

  Widget _buildExpandedHeader() {
    final title = widget.panelMode == ControllerPanelMode.use
        ? context.l10n.options.secondaryControls
        : context.l10n.editControls.title;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'momo',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.l10n.editControls.editMode,
              style: const TextStyle(
                fontFamily: 'momo',
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Switch(
              value: widget.panelMode == ControllerPanelMode.edit,
              onChanged: (val) {
                widget.onPanelModeChanged(
                  val ? ControllerPanelMode.edit : ControllerPanelMode.use,
                );
              },
              activeColor: AppColors.highlightColor,
              activeTrackColor: AppColors.textPrimary.withValues(alpha: 0.3),
              inactiveThumbColor: AppColors.greyDisabled,
              inactiveTrackColor: AppColors.textPrimary.withValues(alpha: 0.1),
            ),
          ],
        ),
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

class _ControllerDpad extends StatefulWidget {
  const _ControllerDpad({
    required this.onButtonStateChanged,
    this.isMini = false,
  });

  final ControllerButtonStateCallback onButtonStateChanged;
  final bool isMini;

  @override
  State<_ControllerDpad> createState() => _ControllerDpadState();
}

class _ControllerDpadState extends State<_ControllerDpad> {
  List<String> _activeDirections = [];
  int? _pointerId;

  // --- CONFIGURATION FOR 8-DIRECTIONAL DPAD ---
  // The center of each diagonal is at 45° (down-right), 135° (down-left), 225° (up-left), and 315° (up-right).
  // If the touch angle is within this half-width of a diagonal angle, it triggers a diagonal press.
  // Otherwise, it falls back to a cardinal direction.
  static const double diagonalConeHalfWidthDegrees = 15.0;

  void _updateDirection(Offset localPosition, Size size) {
    final center = Offset(144.0, size.height - 137.0);
    final delta = localPosition - center;

    if (delta.distance < 30) {
      _releaseDirection();
      return;
    }

    // Convert direction to degrees in [0, 360) range
    double angleDegrees = delta.direction * 180 / math.pi;
    if (angleDegrees < 0) {
      angleDegrees += 360.0;
    }

    List<String> newDirs = [];

    // Check diagonal cones
    if (angleDegrees >= 45.0 - diagonalConeHalfWidthDegrees && angleDegrees <= 45.0 + diagonalConeHalfWidthDegrees) {
      newDirs = ['DOWN', 'RIGHT'];
    } else if (angleDegrees >= 135.0 - diagonalConeHalfWidthDegrees && angleDegrees <= 135.0 + diagonalConeHalfWidthDegrees) {
      newDirs = ['DOWN', 'LEFT'];
    } else if (angleDegrees >= 225.0 - diagonalConeHalfWidthDegrees && angleDegrees <= 225.0 + diagonalConeHalfWidthDegrees) {
      newDirs = ['UP', 'LEFT'];
    } else if (angleDegrees >= 315.0 - diagonalConeHalfWidthDegrees && angleDegrees <= 315.0 + diagonalConeHalfWidthDegrees) {
      newDirs = ['UP', 'RIGHT'];
    }
    // Check cardinal zones
    else if (angleDegrees >= 0.0 && angleDegrees < 45.0 - diagonalConeHalfWidthDegrees || angleDegrees > 315.0 + diagonalConeHalfWidthDegrees) {
      newDirs = ['RIGHT'];
    } else if (angleDegrees > 45.0 + diagonalConeHalfWidthDegrees && angleDegrees < 135.0 - diagonalConeHalfWidthDegrees) {
      newDirs = ['DOWN'];
    } else if (angleDegrees > 135.0 + diagonalConeHalfWidthDegrees && angleDegrees < 225.0 - diagonalConeHalfWidthDegrees) {
      newDirs = ['LEFT'];
    } else {
      newDirs = ['UP'];
    }

    // Determine if active directions have changed
    bool changed = _activeDirections.length != newDirs.length ||
        !_activeDirections.every((d) => newDirs.contains(d));

    if (changed) {
      // Release directions that are no longer active
      for (var d in _activeDirections) {
        if (!newDirs.contains(d)) {
          widget.onButtonStateChanged(d, 'up');
        }
      }
      // Press directions that are newly active
      for (var d in newDirs) {
        if (!_activeDirections.contains(d)) {
          widget.onButtonStateChanged(d, 'down');
        }
      }

      _activeDirections = newDirs;
      HapticsManager.instance.softTap();
      setState(() {});
    }
  }

  void _releaseDirection() {
    for (var d in _activeDirections) {
      widget.onButtonStateChanged(d, 'up');
    }
    if (_activeDirections.isNotEmpty) {
      setState(() {
        _activeDirections = [];
      });
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_pointerId != null) return;
    debugPrint('LEFT DOWN pointer=${event.pointer}');
    _pointerId = event.pointer;
    final RenderBox box = context.findRenderObject() as RenderBox;
    _updateDirection(event.localPosition, box.size);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointerId) return;
    debugPrint('LEFT MOVE pointer=${event.pointer}');
    final RenderBox box = context.findRenderObject() as RenderBox;
    _updateDirection(event.localPosition, box.size);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer == _pointerId) {
      debugPrint('LEFT UP pointer=${event.pointer}');
      _pointerId = null;
      _releaseDirection();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer == _pointerId) {
      debugPrint('LEFT UP pointer=${event.pointer}');
      _pointerId = null;
      _releaseDirection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dpadWidget = SizedBox(
      width: 240,
      height: 258,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _DPadButton(
            label: '',
            isActive: _activeDirections.contains('UP'),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DPadButton(
                label: '',
                isActive: _activeDirections.contains('LEFT'),
              ),
              _DPadButton(
                label: '',
                isActive: _activeDirections.contains('RIGHT'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DPadButton(
            label: '',
            isActive: _activeDirections.contains('DOWN'),
          ),
        ],
      ),
    );

    if (widget.isMini) {
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: dpadWidget,
      );
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: RepaintBoundary(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.only(left: 24.0, bottom: 8.0),
          child: dpadWidget,
        ),
      ),
    );
  }
}

class _DPadButton extends StatefulWidget {
  final String label;
  final bool isActive;

  const _DPadButton({required this.label, required this.isActive});

  @override
  State<_DPadButton> createState() => _DPadButtonState();
}

class _DPadButtonState extends State<_DPadButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (widget.isActive) {
      _animController.value = 0.6;
    }
  }

  @override
  void didUpdateWidget(covariant _DPadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _animController.animateTo(0.6,
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOutQuad);
      } else {
        _animController.forward(from: 0.6);
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.isActive
        ? AppColors.highlightColor
        : AppColors.backgroundColor;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        double value = _animController.value;
        double scaleX = 1.0;
        double scaleY = 1.0;
        double translateY = 0.0;

        if (widget.isActive) {
          scaleX = 1.0 + (value * 0.08);
          scaleY = 1.0 - (value * 0.08);
          translateY = value * 4.0;
        } else if (_animController.isAnimating) {
          double t = (value - 0.6) / 0.4;
          if (t > 0) {
            double spring = math.sin(t * math.pi * 2.5) * (1.0 - t) * 0.12;
            scaleX = 1.0 - spring;
            scaleY = 1.0 + spring;
            translateY = spring * -4.0;
          }
        }

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(0.0, translateY)
            ..scale(scaleX, scaleY),
          child: AnimatedContainer(
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
              widget.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontFamily: 'momo',
              ),
            ),
          ),
        );
      },
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
              label: '⧉',
              onStateChange: (state) => onButtonStateChanged('SELECT', state),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            height: 56,
            child: ControlButton(
              label: '≡',
              onStateChange: (state) => onButtonStateChanged('START', state),
            ),
          ),
        ],
      ),
    );
  }
}

void _showEditNameDialog(
  BuildContext context,
  String currentName,
  ValueChanged<String> onNameChanged,
  Future<String> Function() onRequestRandomName,
  PlayerFaceData playerFace,
) {
  final noNamePlaceholder = context.l10n.editName.noName;
  final controller = TextEditingController(text: currentName == noNamePlaceholder ? '' : currentName);
  bool isLoading = false;

  showDialog(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      final mediaQuery = MediaQuery.of(context);
      final isLandscape = mediaQuery.size.width > mediaQuery.size.height;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 16 : 40,
              vertical: isLandscape ? 8 : 24,
            ),
            child: Container(
              width: isLandscape ? 400 : 320,
              padding: EdgeInsets.all(isLandscape ? 14 : 24),
              decoration: BoxDecoration(
                color: AppColors.screenBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.textPrimary,
                  width: AppColors.borderThickness,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: isLandscape
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.textPrimary.withValues(alpha: 0.2),
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    maxLength: 15,
                                    textAlign: TextAlign.center,
                                    autofocus: true,
                                    style: const TextStyle(
                                      fontFamily: 'momo_sans',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      border: InputBorder.none,
                                      hintText: context.l10n.editName.hint,
                                      isDense: true,
                                    ),
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (value) {
                                      final trimmed = value.trim();
                                      if (trimmed.isNotEmpty) {
                                        onNameChanged(trimmed);
                                      }
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.textPrimary,
                                        ),
                                      )
                                    : GestureDetector(
                                        onTap: () async {
                                          setDialogState(() {
                                            isLoading = true;
                                          });
                                          final randomName = await onRequestRandomName();
                                          if (randomName.isNotEmpty) {
                                            controller.text = randomName;
                                            controller.selection = TextSelection.collapsed(
                                              offset: randomName.length,
                                            );
                                          }
                                          setDialogState(() {
                                            isLoading = false;
                                          });
                                        },
                                        child: const Icon(
                                          Icons.casino_outlined,
                                          color: AppColors.textPrimary,
                                          size: 28,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            final trimmed = controller.text.trim();
                            if (trimmed.isNotEmpty) {
                              onNameChanged(trimmed);
                            }
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.highlightColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.textPrimary,
                                width: AppColors.borderThickness / 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: AppColors.textPrimary,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.editName.title,
                          style: const TextStyle(
                            fontFamily: 'momo',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.textPrimary.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  maxLength: 15,
                                  textAlign: TextAlign.center,
                                  autofocus: true,
                                  style: const TextStyle(
                                    fontFamily: 'momo_sans',
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    border: InputBorder.none,
                                    hintText: context.l10n.editName.hint,
                                    isDense: true,
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (value) {
                                    final trimmed = value.trim();
                                    if (trimmed.isNotEmpty) {
                                      onNameChanged(trimmed);
                                    }
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.textPrimary,
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap: () async {
                                        setDialogState(() {
                                          isLoading = true;
                                        });
                                        final randomName = await onRequestRandomName();
                                        if (randomName.isNotEmpty) {
                                          controller.text = randomName;
                                          controller.selection = TextSelection.collapsed(
                                            offset: randomName.length,
                                          );
                                        }
                                        setDialogState(() {
                                          isLoading = false;
                                        });
                                      },
                                      child: const Icon(
                                        Icons.casino_outlined,
                                        color: AppColors.textPrimary,
                                        size: 28,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                context.l10n.common.cancel,
                                style: TextStyle(
                                  fontFamily: 'momo',
                                  color: AppColors.textPrimary.withValues(alpha: 0.6),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.highlightColor,
                                foregroundColor: AppColors.textPrimary,
                                elevation: 0,
                                side: const BorderSide(
                                    color: AppColors.textPrimary,
                                    width: AppColors.borderThickness / 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              ),
                              onPressed: () {
                                final trimmed = controller.text.trim();
                                if (trimmed.isNotEmpty) {
                                  onNameChanged(trimmed);
                                }
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                context.l10n.common.save,
                                style: const TextStyle(
                                  fontFamily: 'momo',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          );
        },
      );
    },
  );
}

class _PlayerNameWidget extends StatelessWidget {
  final String? name;
  final ValueChanged<String> onNameChanged;
  final Future<String> Function() onRequestRandomName;
  final PlayerFaceData playerFace;

  const _PlayerNameWidget({
    required this.name,
    required this.onNameChanged,
    required this.onRequestRandomName,
    required this.playerFace,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name ?? context.l10n.editName.noName;

    return GestureDetector(
      onTap: () => _showEditNameDialog(
        context,
        displayName,
        onNameChanged,
        onRequestRandomName,
        playerFace,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'momo_sans',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dashed,
          ),
        ),
      ),
    );
  }
}

class _AvailableButtonsPanel extends StatelessWidget {
  const _AvailableButtonsPanel({
    required this.brandingMode,
    required this.isDragging,
    required this.buttons,
    required this.rightStickControls,
    required this.onButtonDropped,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.tapHapticsEnabled,
  });

  final ControllerBrandingMode brandingMode;
  final bool isDragging;
  final List<String> buttons;
  final List<String> rightStickControls;
  final ValueChanged<String> onButtonDropped;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;
  final bool tapHapticsEnabled;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        return !buttons.contains(details.data) && !rightStickControls.contains(details.data);
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
                context.l10n.editControls.availableButtons,
                style: TextStyle(
                  fontFamily: 'momo',
                  fontSize: 20,
                  color: AppColors.textPrimary.withValues(
                    alpha: isTarget ? 1.0 : 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
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
                      const SizedBox(height: 24),
                      Text(
                        context.l10n.editControls.rightStickControls,
                        style: TextStyle(
                          fontFamily: 'momo',
                          fontSize: 20,
                          color: AppColors.textPrimary.withValues(
                            alpha: isTarget ? 1.0 : 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: rightStickControls.map((buttonKey) {
                          String label = '';
                          Widget? labelWidget;
                          if (buttonKey == 'RS_BUTTON') {
                            label = 'RS Btn';
                            labelWidget = const Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam_rounded, size: 16, color: AppColors.textPrimary),
                                SizedBox(width: 4),
                                Text('RS Btn', style: TextStyle(fontFamily: 'momo', fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            );
                          } else if (buttonKey == 'RS_FIXED') {
                            label = 'Fixed RS';
                            labelWidget = const Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.adjust_rounded, size: 16, color: AppColors.textPrimary),
                                SizedBox(width: 4),
                                Text('Fixed RS', style: TextStyle(fontFamily: 'momo', fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            );
                          } else if (buttonKey == 'RS_SWIPE') {
                            label = 'Swipe Pad';
                            labelWidget = const Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.visibility_rounded, size: 16, color: AppColors.textPrimary),
                                SizedBox(width: 4),
                                Text('Swipe Pad', style: TextStyle(fontFamily: 'momo', fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            );
                          }

                          return DraggableEditButton(
                            btnId: buttonKey,
                            label: label,
                            labelWidget: labelWidget,
                            onDragStarted: onDragStarted,
                            onDragEnded: onDragEnded,
                            tapHapticsEnabled: tapHapticsEnabled,
                            baseColor: AppColors.backgroundColor.withValues(
                              alpha: 0.2,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
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
