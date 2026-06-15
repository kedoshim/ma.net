import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/controller_branding.dart';
import '../services/haptics_manager.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'right_stick_controls.dart';

int _failedDragTaps = 0;

typedef ButtonStateCallback = void Function(String xinputId, String state);

class ActionButtons extends StatefulWidget {
  final ControllerBrandingMode brandingMode;
  final Map<String, bool> visibleButtons;
  final List<String> buttonOrder;
  final ButtonStateCallback onButtonStateChanged;
  final bool editMode;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;
  final bool tapHapticsEnabled;
  final void Function(List<String> order)? onButtonOrderChanged;
  final ValueChanged<bool>? onAnyButtonPressed;
  final ValueChanged<Offset>? onRightStickChanged;
  final VoidCallback? onRightStickRelease;
  final Map<String, int> buttonSizes;
  final void Function(Map<String, int> sizes)? onButtonSizesChanged;
  final String rightLayoutMode;
  final double rightStickSensitivity;
  final double swipeAccelerationIntensity;
  final double rightStickAntiDeadzone;
  final double rightStickResponseCurve;

  const ActionButtons({
    super.key,
    required this.brandingMode,
    required this.visibleButtons,
    required this.buttonOrder,
    required this.onButtonStateChanged,
    required this.editMode,
    this.onDragStarted,
    this.onDragEnded,
    this.tapHapticsEnabled = false,
    this.onButtonOrderChanged,
    this.onAnyButtonPressed,
    this.onRightStickChanged,
    this.onRightStickRelease,
    this.buttonSizes = const {},
    this.onButtonSizesChanged,
    this.rightLayoutMode = 'columns',
    this.rightStickSensitivity = 1.0,
    this.swipeAccelerationIntensity = 0.0,
    this.rightStickAntiDeadzone = 0.10,
    this.rightStickResponseCurve = 0.5,
  });

  @override
  State<ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<ActionButtons> {
  late List<String> _buttonOrder;

  // Default button order
  static const List<String> _defaultButtonOrder = [
    'Y',
    'B',
    'X',
    'A',
    'RB',
    'RT',
    'LB',
    'LT',
    'R',
    'L',
    'RS_BUTTON',
    'RS_FIXED',
    'RS_SWIPE',
  ];

  @override
  void initState() {
    super.initState();
    _buttonOrder = _normalizeOrder(widget.buttonOrder);
  }

  @override
  void didUpdateWidget(covariant ActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buttonOrder != widget.buttonOrder) {
      _buttonOrder = _normalizeOrder(widget.buttonOrder);
    }
  }

  List<String> _normalizeOrder(List<String> input) {
    final sanitized = <String>[];
    for (final item in input) {
      if (_defaultButtonOrder.contains(item) && !sanitized.contains(item)) {
        sanitized.add(item);
      }
    }
    for (final item in _defaultButtonOrder) {
      if (!sanitized.contains(item)) {
        sanitized.add(item);
      }
    }
    return sanitized;
  }

  void _reorderButtons(String draggedId, String targetId) {
    final draggedIndex = _buttonOrder.indexOf(draggedId);
    final targetIndex = _buttonOrder.indexOf(targetId);

    if (draggedIndex == -1 ||
        targetIndex == -1 ||
        draggedIndex == targetIndex) {
      return;
    }

    final temp = _buttonOrder[draggedIndex];
    _buttonOrder[draggedIndex] = _buttonOrder[targetIndex];
    _buttonOrder[targetIndex] = temp;

    setState(() {});
    widget.onButtonOrderChanged?.call(List<String>.from(_buttonOrder));
  }

  List<String> _getVisibleButtons() {
    return _buttonOrder
        .where((btnId) => widget.visibleButtons[btnId] != false)
        .toList();
  }

  List<List<String>> _splitIntoColumns(List<String> buttons) {
    final left = <String>[];
    final right = <String>[];

    for (final button in buttons) {
      if (left.length <= right.length) {
        left.add(button);
      } else {
        right.add(button);
      }
    }

    // ensure the smaller column stays on the left
    if (left.length > right.length) {
      return [right, left];
    }

    return [left, right];
  }

  List<List<String>> _splitIntoRows(List<String> buttons) {
    final top = <String>[];
    final bottom = <String>[];

    for (final button in buttons) {
      if (top.length <= bottom.length) {
        top.add(button);
      } else {
        bottom.add(button);
      }
    }

    // ensure the larger/equal row stays on top
    if (top.length < bottom.length) {
      return [bottom, top];
    }

    return [top, bottom];
  }

  Widget _buildRow(List<String> buttons) {
    return Expanded(
      child: Row(
        children: buttons
            .map(
              (btnId) {
                final defaultFlex = btnId == 'RS_SWIPE' ? 2 : 1;
                final flex = widget.buttonSizes[btnId] ?? defaultFlex;
                return Expanded(
                  flex: flex,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: widget.editMode
                        ? _buildEditModeButton(btnId)
                        : _buildGameButton(btnId),
                  ),
                );
              },
            )
            .toList(),
      ),
    );
  }

  Widget _buildColumn(List<String> buttons) {
    return Expanded(
      child: Column(
        children: buttons
            .map(
              (btnId) {
                final defaultFlex = btnId == 'RS_SWIPE' ? 2 : 1;
                final flex = widget.buttonSizes[btnId] ?? defaultFlex;
                return Expanded(
                  flex: flex,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: widget.editMode
                        ? _buildEditModeButton(btnId)
                        : _buildGameButton(btnId),
                  ),
                );
              },
            )
            .toList(),
      ),
    );
  }

  Widget _buildGameButton(String btnId) {
    if (btnId == 'RS_BUTTON') {
      final output = RightStickOutput(
        config: RightStickConfig(
          sensitivity: widget.rightStickSensitivity,
          antiDeadzone: widget.rightStickAntiDeadzone,
          responseCurve: widget.rightStickResponseCurve,
        ),
        onSendValue: (x, y) => widget.onRightStickChanged?.call(Offset(x, y)),
        onReleased: () => widget.onRightStickRelease?.call(),
      );
      return FloatingRightStick(
        output: output,
        tapHapticsEnabled: widget.tapHapticsEnabled,
      );
    } else if (btnId == 'RS_FIXED') {
      final output = RightStickOutput(
        config: RightStickConfig(
          sensitivity: widget.rightStickSensitivity,
          antiDeadzone: widget.rightStickAntiDeadzone,
          responseCurve: widget.rightStickResponseCurve,
        ),
        onSendValue: (x, y) => widget.onRightStickChanged?.call(Offset(x, y)),
        onReleased: () => widget.onRightStickRelease?.call(),
      );
      return FixedRightStick(
        output: output,
        tapHapticsEnabled: widget.tapHapticsEnabled,
      );
    } else if (btnId == 'RS_SWIPE') {
      final output = RightStickOutput(
        config: RightStickConfig(
          sensitivity: widget.rightStickSensitivity,
          swipeAccelerationIntensity: widget.swipeAccelerationIntensity,
          antiDeadzone: widget.rightStickAntiDeadzone,
          responseCurve: widget.rightStickResponseCurve,
        ),
        onSendValue: (x, y) => widget.onRightStickChanged?.call(Offset(x, y)),
        onReleased: () => widget.onRightStickRelease?.call(),
      );
      return RightStickSwipePad(
        output: output,
        tapHapticsEnabled: widget.tapHapticsEnabled,
      );
    }

    final btnConfig = getButtonConfig(btnId);
    final presentation = ControllerBranding.presentationFor(
      btnConfig.xinput,
      widget.brandingMode,
    );

    return GameButton(
      label: presentation.shortLabel,
      labelWidget: ControllerButtonBrand(presentation: presentation, size: 28),
      onStateChange: (state) =>
          widget.onButtonStateChanged(btnConfig.xinput, state),
      onPressedChanged: widget.onAnyButtonPressed,
      tapHapticsEnabled: widget.tapHapticsEnabled,
    );
  }

  Widget _buildEditModeButton(String btnId) {
    final isRS = btnId == 'RS_BUTTON' || btnId == 'RS_FIXED' || btnId == 'RS_SWIPE';
    Widget child;

    if (isRS) {
      String label = '';
      Widget? labelWidget;
      BorderRadius? customBorderRadius;
      bool isGhost = false;

      if (btnId == 'RS_BUTTON') {
        label = '';
        isGhost = true;
        labelWidget = const RightStickFloatingPreview(faded: true);
      } else if (btnId == 'RS_FIXED') {
        label = '';
        customBorderRadius = BorderRadius.circular(36);
        labelWidget = const RightStickFixedPreview();
      } else if (btnId == 'RS_SWIPE') {
        label = '';
        labelWidget = const RightStickSwipePreview();
      }

      child = DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          return widget.visibleButtons[details.data] == true &&
              details.data != btnId;
        },
        onAcceptWithDetails: (details) {
          _reorderButtons(details.data, btnId);
        },
        builder: (context, candidateData, rejectedData) {
          final isDragTarget = candidateData.isNotEmpty;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              DraggableEditButton(
                btnId: btnId,
                label: label,
                labelWidget: labelWidget,
                isDragTarget: isDragTarget,
                onDragStarted: widget.onDragStarted,
                onDragEnded: widget.onDragEnded,
                tapHapticsEnabled: widget.tapHapticsEnabled,
                width: double.infinity,
                height: double.infinity,
                borderRadius: customBorderRadius,
                isGhost: isGhost,
                baseColor: AppColors.backgroundColor,
              ),
              if (btnId == 'RS_SWIPE' || btnId == 'RS_BUTTON')
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      if (widget.tapHapticsEnabled) {
                        HapticsManager.instance.softTap();
                      }
                      final currentSizes = Map<String, int>.from(widget.buttonSizes);
                      final defaultFlex = btnId == 'RS_SWIPE' ? 2 : 1;
                      final currentFlex = currentSizes[btnId] ?? defaultFlex;
                      final nextFlex = currentFlex == 1 ? 2 : 1;
                      currentSizes[btnId] = nextFlex;
                      widget.onButtonSizesChanged?.call(currentSizes);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                      child: Icon(
                        (widget.buttonSizes[btnId] ?? (btnId == 'RS_SWIPE' ? 2 : 1)) == 1
                            ? Icons.aspect_ratio_rounded
                            : Icons.compress_rounded,
                        size: 14,
                        color: AppColors.lightColor,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    } else {
      final btnConfig = getButtonConfig(btnId);
      final presentation = ControllerBranding.presentationFor(
        btnConfig.xinput,
        widget.brandingMode,
      );

      child = DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          return widget.visibleButtons[details.data] == true &&
              details.data != btnId;
        },
        onAcceptWithDetails: (details) {
          _reorderButtons(details.data, btnId);
        },
        builder: (context, candidateData, rejectedData) {
          final isDragTarget = candidateData.isNotEmpty;

          return DraggableEditButton(
            btnId: btnId,
            label: presentation.shortLabel,
            labelWidget: ControllerButtonBrand(
              presentation: presentation,
              size: 24,
            ),
            isDragTarget: isDragTarget,
            onDragStarted: widget.onDragStarted,
            onDragEnded: widget.onDragEnded,
            tapHapticsEnabled: widget.tapHapticsEnabled,
            width: double.infinity,
            height: double.infinity,
            baseColor: AppColors.backgroundColor,
          );
        },
      );
    }

    return child;
  }

  // Helper method removed and replaced by global getButtonConfig

  @override
  Widget build(BuildContext context) {
    final visible = _getVisibleButtons();
    if (visible.isEmpty) {
      return Center(
        child: Text(
          widget.editMode
              ? context.l10n.editControls.noButtonsVisible
              : context.l10n.editControls.enableButtonsInSettings,
          style: TextStyle(
            fontFamily: 'momo',
            fontSize: 14,
            color: AppColors.textPrimary.withValues(alpha: 0.54),
          ),
        ),
      );
    }

    if (visible.length == 1) {
      if (widget.rightLayoutMode == 'rows') {
        return Column(
          children: [
            _buildRow(visible),
          ],
        );
      } else {
        return Row(
          children: [
            _buildColumn(visible),
          ],
        );
      }
    }

    if (widget.rightLayoutMode == 'rows') {
      final rows = _splitIntoRows(visible);
      return Column(
        children: [
          _buildRow(rows[0]),
          const SizedBox(height: 8),
          _buildRow(rows[1]),
        ],
      );
    } else {
      final columns = _splitIntoColumns(visible);
      return Row(
        children: [
          _buildColumn(columns[0]),
          const SizedBox(width: 8),
          _buildColumn(columns[1]),
        ],
      );
    }
  }
}

class ButtonConfig {
  final String id;
  final String label;
  final String xinput;

  const ButtonConfig(this.id, this.label, this.xinput);
}

ButtonConfig getButtonConfig(String btnId) {
  const allButtons = [
    ButtonConfig('Y', 'Y', 'Y'),
    ButtonConfig('B', 'B', 'B'),
    ButtonConfig('X', 'X', 'X'),
    ButtonConfig('A', 'A', 'A'),
    ButtonConfig('RB', 'RB', 'RB'),
    ButtonConfig('RT', 'RT', 'RT'),
    ButtonConfig('LB', 'LB', 'LB'),
    ButtonConfig('LT', 'LT', 'LT'),
    ButtonConfig('R', 'R', 'R'),
    ButtonConfig('L', 'L', 'L'),
  ];

  try {
    return allButtons.firstWhere((btn) => btn.id == btnId);
  } catch (e) {
    return const ButtonConfig('unknown', '?', 'UNKNOWN');
  }
}

class GameButton extends StatefulWidget {
  final String label;
  final Widget? labelWidget;
  final void Function(String state) onStateChange;
  final ValueChanged<bool>? onPressedChanged;
  final bool tapHapticsEnabled;

  const GameButton({
    required this.label,
    this.labelWidget,
    required this.onStateChange,
    this.onPressedChanged,
    this.tapHapticsEnabled = false,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  int? _pointerId;
  late AnimationController _animController;

  static const double _retentionMargin = 32.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    if (value) {
      _animController.animateTo(0.6,
          duration: const Duration(milliseconds: 50), curve: Curves.easeOutQuad);
      if (widget.tapHapticsEnabled) {
        try {
          HapticsManager.instance.softTap();
        } catch (_) {}
      }
    } else {
      _animController.forward(from: 0.6);
    }
    widget.onStateChange(value ? 'down' : 'up');
    widget.onPressedChanged?.call(value);
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  bool _isInsideRetention(Offset localPosition, Size size) {
    return localPosition.dx >= -_retentionMargin &&
        localPosition.dx <= size.width + _retentionMargin &&
        localPosition.dy >= -_retentionMargin &&
        localPosition.dy <= size.height + _retentionMargin;
  }

  @override
  Widget build(BuildContext context) {
    final background = (_hovered || _pressed)
        ? AppColors.highlightColor
        : AppColors.backgroundColor;

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (_pointerId != null) return;
          _pointerId = event.pointer;
          _setPressed(true);
        },
        onPointerMove: (event) {
          if (event.pointer != _pointerId) return;
          final RenderBox box = context.findRenderObject() as RenderBox;
          final isInside = _isInsideRetention(event.localPosition, box.size);
          if (_pressed && !isInside) {
            _setPressed(false);
          } else if (!_pressed && isInside) {
            _setPressed(true);
          }
        },
        onPointerUp: (event) {
          if (event.pointer == _pointerId) {
            _pointerId = null;
            _setPressed(false);
          }
        },
        onPointerCancel: (event) {
          if (event.pointer == _pointerId) {
            _pointerId = null;
            _setPressed(false);
          }
        },
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            double value = _animController.value;
            double scaleX = 1.0;
            double scaleY = 1.0;
            double translateY = 0.0;

            if (_pressed) {
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
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textPrimary,
                width: AppColors.borderThickness,
              ),
            ),
            child: widget.labelWidget ??
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'momo',
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

class DraggableEditButton extends StatefulWidget {
  final String btnId;
  final String label;
  final Widget? labelWidget;
  final bool isDragTarget;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;
  final Color baseColor;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool isGhost;
  final bool tapHapticsEnabled;

  const DraggableEditButton({
    super.key,
    required this.btnId,
    required this.label,
    this.labelWidget,
    this.isDragTarget = false,
    this.onDragStarted,
    this.onDragEnded,
    required this.baseColor,
    this.width,
    this.height,
    this.borderRadius,
    this.isGhost = false,
    this.tapHapticsEnabled = false,
  });

  @override
  State<DraggableEditButton> createState() => _DraggableEditButtonState();
}

class _DraggableEditButtonState extends State<DraggableEditButton>
    with TickerProviderStateMixin {
  late AnimationController _wobbleController;
  late AnimationController _idleController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.tapHapticsEnabled) {
      HapticsManager.instance.softTap();
    }
    _failedDragTaps++;
    if (_failedDragTaps >= 3) {
      _failedDragTaps = 0;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.touch_app_rounded, color: AppColors.lightColor),
              const SizedBox(width: 12),
              Text(
                context.l10n.editControls.dragToMove,
                style: const TextStyle(fontFamily: 'momo', fontSize: 16),
              ),
            ],
          ),
          backgroundColor: AppColors.textPrimary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(24),
        ),
      );
    }
    _wobbleController.forward(from: 0);
  }

  Widget _buildContent({required double opacity, bool isFeedback = false}) {
    final finalBorderRadius = widget.borderRadius ?? BorderRadius.circular(16);
    
    final borderColor = widget.isDragTarget
        ? Colors.green
        : (widget.isGhost ? AppColors.textPrimary.withValues(alpha: 0.3) : AppColors.textPrimary);
    
    final borderWidth = widget.isDragTarget ? 3.0 : 2.0;
    
    final bgColor = widget.isDragTarget
        ? AppColors.dragTargetGreen.withValues(alpha: 0.8)
        : (widget.isGhost ? AppColors.backgroundColor.withValues(alpha: 0.05) : widget.baseColor);

    return Opacity(
      opacity: opacity,
      child: Container(
        width: isFeedback ? 96 : (widget.width ?? 96),
        height: isFeedback ? 80 : widget.height,
        constraints: isFeedback
            ? null
            : (widget.height != null ? null : const BoxConstraints(minHeight: 64)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: finalBorderRadius,
          border: Border.all(
            color: borderColor.withValues(alpha: opacity),
            width: borderWidth,
          ),
          boxShadow: opacity > 0.5 && !widget.isDragTarget && !widget.isGhost
              ? [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.15),
                    blurRadius: isFeedback ? 12 : 6,
                    offset: isFeedback
                        ? const Offset(0, 8)
                        : const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 16,
                  color: AppColors.textPrimary.withValues(alpha: widget.isGhost ? 0.2 : 0.4),
                ),
                const SizedBox(height: 4),
                if (widget.labelWidget != null)
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: AppColors.textPrimary.withValues(alpha: opacity),
                      ),
                      child: widget.labelWidget!,
                    ),
                  )
                else
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary.withValues(alpha: opacity),
                      fontFamily: 'momo',
                    ),
                  ),
              ],
            ),
            AnimatedBuilder(
              animation: _wobbleController,
              builder: (context, child) {
                if (_wobbleController.isDismissed) {
                  return const SizedBox.shrink();
                }
                final t = _wobbleController.value;
                final op = math.sin(t * math.pi);
                final dy = -20.0 * t;
                return Positioned(
                  top: 0,
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Opacity(
                      opacity: op,
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: LongPressDraggable<String>(
        data: widget.btnId,
        delay: const Duration(milliseconds: 150),
        onDragStarted: () {
          _failedDragTaps = 0;
          setState(() => _isPressed = false);
          widget.onDragStarted?.call();
        },
        onDragEnd: (_) => widget.onDragEnded?.call(),
        feedback: Material(
          color: Colors.transparent,
          child: _buildContent(opacity: 0.9, isFeedback: true),
        ),
        childWhenDragging: _buildContent(opacity: 0.3),
        child: AnimatedBuilder(
          animation: Listenable.merge([_wobbleController, _idleController]),
          builder: (context, child) {
            final wT = _wobbleController.value;
            final wobbleRot = math.sin(wT * math.pi * 4) * 0.1 * (1 - wT);
            final wobbleScale = 1.0 + math.sin(wT * math.pi) * 0.15;
            final wobbleY = -math.sin(wT * math.pi) * 8.0;

            final iT = _idleController.value;
            final idleY = widget.isDragTarget
                ? 0.0
                : math.sin(iT * math.pi) * 2.0;

            final scale = _isPressed ? 0.95 : wobbleScale;

            return Transform(
              transform: Matrix4.identity()
                ..translateByDouble(0.0, wobbleY + idleY, 0.0, 1.0)
                ..scaleByDouble(scale, scale, 1.0, 1.0)
                ..rotateZ(wobbleRot),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: _buildContent(opacity: 1.0),
        ),
      ),
    );
  }
}
