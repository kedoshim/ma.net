import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/haptics_manager.dart';
import '../services/gamepad_input_engine.dart';

class RightStickConfig {
  final double sensitivity;
  final bool invertX;
  final bool invertY;
  final double returnToCenterSpeed;
  final double deadzone;
  final double swipeAccelerationIntensity;
  final double antiDeadzone;
  final double responseCurve;

  const RightStickConfig({
    this.sensitivity = 1.0,
    this.invertX = false,
    this.invertY = false,
    this.returnToCenterSpeed = 0.2,
    this.deadzone = 0.05,
    this.swipeAccelerationIntensity = 0.0,
    this.antiDeadzone = 0.10,
    this.responseCurve = 0.5,
  });
}

class RightStickOutput {
  final RightStickConfig config;
  final void Function(double x, double y) onSendValue;
  final VoidCallback onReleased;

  RightStickOutput({
    required this.config,
    required this.onSendValue,
    required this.onReleased,
  });

  void processRawInput(double rawX, double rawY) {
    // Kept to maintain backward compatibility.
  }

  void release() {
    // Kept to maintain backward compatibility.
  }
}

RenderBox? _getVirtualRoot(BuildContext context) {
  try {
    final overlay = Overlay.of(context);
    return overlay.context.findRenderObject() as RenderBox?;
  } catch (_) {
    return null;
  }
}

class FloatingRightStick extends StatefulWidget {
  final RightStickOutput output;
  final bool tapHapticsEnabled;

  const FloatingRightStick({
    super.key,
    required this.output,
    this.tapHapticsEnabled = false,
  });

  @override
  State<FloatingRightStick> createState() => _FloatingRightStickState();
}

class _FloatingRightStickState extends State<FloatingRightStick>
    with TickerProviderStateMixin {
  late AnimationController _appearController;

  final ValueNotifier<Offset> _visualOffset = ValueNotifier(Offset.zero);
  final ValueNotifier<bool> _active = ValueNotifier(false);
  final ValueNotifier<Offset> _basePos = ValueNotifier(Offset.zero);

  static const double baseSize = 150.0;
  static const double stickSize = 50.0;

  @override
  void initState() {
    super.initState();
    debugPrint('[INSTRUMENTATION] FloatingRightStick state created. State Hash: ${identityHashCode(this)}');
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: 0.0,
    );
    _active.addListener(_onActiveChanged);
  }

  @override
  void dispose() {
    debugPrint('[INSTRUMENTATION] FloatingRightStick state disposed. State Hash: ${identityHashCode(this)}');
    _active.removeListener(_onActiveChanged);
    GamepadInputEngine.instance.releaseRightIfMatched(identityHashCode(this));
    _appearController.dispose();
    _visualOffset.dispose();
    _active.dispose();
    _basePos.dispose();
    super.dispose();
  }

  void _onActiveChanged() {
    if (!mounted) return;
    if (_active.value) {
      _appearController.forward(from: 0.0);
    } else {
      _appearController.reverse();
    }
  }

  Offset _clampBase(Offset proposedLocalBase) {
    if (!mounted) return proposedLocalBase;
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final rootBox = _getVirtualRoot(context);
    if (renderBox != null && rootBox != null) {
      final globalBase = renderBox.localToGlobal(proposedLocalBase);
      final baseOverlay = rootBox.globalToLocal(globalBase);
      final double padding = baseSize / 2;
      final clampedOverlay = Offset(
        baseOverlay.dx.clamp(padding, rootBox.size.width - padding),
        baseOverlay.dy.clamp(padding, rootBox.size.height - padding),
      );
      return renderBox.globalToLocal(rootBox.localToGlobal(clampedOverlay));
    }
    return proposedLocalBase;
  }

  void _handlePointerDown(PointerDownEvent event) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    debugPrint('[INSTRUMENTATION] FloatingRightStick pointer down. State Hash: ${identityHashCode(this)}, Position: ${event.position}, LocalPosition: ${renderBox.globalToLocal(event.position)}, Size: $size');

    if (widget.tapHapticsEnabled) {
      try {
        HapticsManager.instance.softTap();
      } catch (_) {}
    }

    GamepadInputEngine.instance.handleRightPointerDown(
      event: event,
      parentSize: size,
      layout: 'RS_BUTTON',
      config: widget.output.config,
      converter: (globalPos) {
        if (!mounted) return globalPos;
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box != null && box.attached) {
          return box.globalToLocal(globalPos);
        }
        return globalPos;
      },
      visualOffset: _visualOffset,
      active: _active,
      basePos: _basePos,
      controlId: 'RS-BUTTON_${identityHashCode(this)}',
      controlHashCode: identityHashCode(this),
      baseSize: baseSize,
      clampBase: _clampBase,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellBounds = constraints.biggest;

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          child: RepaintBoundary(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Activation Cell (idle button state)
                ValueListenableBuilder<bool>(
                  valueListenable: _active,
                  builder: (context, active, child) {
                    if (active) return const SizedBox.shrink();
                    return const RightStickFloatingPreview(faded: true);
                  },
                ),

                // Overlay Floating Joystick
                AnimatedBuilder(
                  animation: _appearController,
                  builder: (context, child) {
                    final showOverlay = _appearController.value > 0;
                    if (!showOverlay) return const SizedBox.shrink();

                    final scale = (0.8 + (_appearController.value * 0.2)) *
                        (_active.value ? 0.92 : 1.0);
                    final opacity = _appearController.value;

                    return ValueListenableBuilder<Offset>(
                      valueListenable: _basePos,
                      builder: (context, basePos, child) {
                        final effectiveBaseOffset = basePos == Offset.zero
                            ? Offset(cellBounds.width / 2, cellBounds.height / 2)
                            : basePos;

                        return ValueListenableBuilder<Offset>(
                          valueListenable: _visualOffset,
                          builder: (context, visualOffset, child) {
                            return Positioned(
                              left: effectiveBaseOffset.dx - baseSize / 2,
                              top: effectiveBaseOffset.dy - baseSize / 2,
                              child: Transform.scale(
                                scale: scale,
                                child: Opacity(
                                  opacity: opacity,
                                  child: SizedBox(
                                    width: baseSize,
                                    height: baseSize,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: baseSize,
                                          height: baseSize,
                                          decoration: BoxDecoration(
                                            color: AppColors.backgroundColor,
                                            borderRadius: BorderRadius.circular(36),
                                            border: Border.all(
                                              color: AppColors.textPrimary,
                                              width: AppColors.borderThickness,
                                            ),
                                          ),
                                        ),
                                        AnimatedPositioned(
                                          duration: _active.value
                                              ? Duration.zero
                                              : const Duration(milliseconds: 300),
                                          curve: _active.value
                                              ? Curves.linear
                                              : Curves.elasticOut,
                                          left: baseSize / 2 - stickSize / 2 + visualOffset.dx,
                                          top: baseSize / 2 - stickSize / 2 + visualOffset.dy,
                                          child: AnimatedScale(
                                            scale: _active.value ? 1.25 : 1.0,
                                            duration: const Duration(milliseconds: 150),
                                            curve: Curves.easeOutBack,
                                            child: Container(
                                              width: stickSize,
                                              height: stickSize,
                                              decoration: BoxDecoration(
                                                color: AppColors.textPrimary,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: AppColors.lightColor,
                                                  width: AppColors.borderThickness,
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
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FixedRightStick extends StatefulWidget {
  final RightStickOutput output;
  final bool tapHapticsEnabled;

  const FixedRightStick({
    super.key,
    required this.output,
    this.tapHapticsEnabled = false,
  });

  @override
  State<FixedRightStick> createState() => _FixedRightStickState();
}

class _FixedRightStickState extends State<FixedRightStick> {
  final ValueNotifier<Offset> _visualOffset = ValueNotifier(Offset.zero);
  final ValueNotifier<bool> _active = ValueNotifier(false);
  final ValueNotifier<Offset> _basePos = ValueNotifier(Offset.zero);

  @override
  void initState() {
    super.initState();
    debugPrint('[INSTRUMENTATION] FixedRightStick state created. State Hash: ${identityHashCode(this)}');
  }

  @override
  void dispose() {
    debugPrint('[INSTRUMENTATION] FixedRightStick state disposed. State Hash: ${identityHashCode(this)}');
    GamepadInputEngine.instance.releaseRightIfMatched(identityHashCode(this));
    _visualOffset.dispose();
    _active.dispose();
    _basePos.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    debugPrint('[INSTRUMENTATION] FixedRightStick pointer down. State Hash: ${identityHashCode(this)}, Position: ${event.position}, LocalPosition: ${renderBox.globalToLocal(event.position)}, Size: $size');

    if (widget.tapHapticsEnabled) {
      try {
        HapticsManager.instance.softTap();
      } catch (_) {}
    }

    final stickSize = math.min(size.width, size.height);

    GamepadInputEngine.instance.handleRightPointerDown(
      event: event,
      parentSize: size,
      layout: 'RS_FIXED',
      config: widget.output.config,
      converter: (globalPos) {
        if (!mounted) return globalPos;
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box != null && box.attached) {
          return box.globalToLocal(globalPos);
        }
        return globalPos;
      },
      visualOffset: _visualOffset,
      active: _active,
      basePos: _basePos,
      controlId: 'RS-FIXED_${identityHashCode(this)}',
      controlHashCode: identityHashCode(this),
      baseSize: stickSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final knobSize = size > 100 ? 40.0 : size * 0.33;
        final borderRadius = size * 0.3;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          child: RepaintBoundary(
            child: Center(
              child: SizedBox(
                width: size,
                height: size,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _active,
                  builder: (context, active, child) {
                    return ValueListenableBuilder<Offset>(
                      valueListenable: _visualOffset,
                      builder: (context, visualOffset, child) {
                        return Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedScale(
                              scale: active ? 0.92 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutBack,
                              child: Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundColor,
                                  borderRadius: BorderRadius.circular(borderRadius),
                                  border: Border.all(
                                    color: AppColors.textPrimary,
                                    width: AppColors.borderThickness,
                                  ),
                                ),
                              ),
                            ),
                            AnimatedPositioned(
                              duration: active ? Duration.zero : const Duration(milliseconds: 300),
                              curve: active ? Curves.linear : Curves.elasticOut,
                              left: size / 2 - knobSize / 2 + visualOffset.dx,
                              top: size / 2 - knobSize / 2 + visualOffset.dy,
                              child: AnimatedScale(
                                scale: active ? 1.25 : 1.0,
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeOutBack,
                                child: Container(
                                  width: knobSize,
                                  height: knobSize,
                                  decoration: BoxDecoration(
                                    color: AppColors.textPrimary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.lightColor,
                                      width: AppColors.borderThickness,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class RightStickSwipePad extends StatefulWidget {
  final RightStickOutput output;
  final bool tapHapticsEnabled;

  const RightStickSwipePad({
    super.key,
    required this.output,
    this.tapHapticsEnabled = false,
  });

  @override
  State<RightStickSwipePad> createState() => _RightStickSwipePadState();
}

class _RightStickSwipePadState extends State<RightStickSwipePad> {
  final ValueNotifier<Offset> _visualOffset = ValueNotifier(Offset.zero);
  final ValueNotifier<bool> _active = ValueNotifier(false);
  final ValueNotifier<Offset> _basePos = ValueNotifier(Offset.zero);

  @override
  void initState() {
    super.initState();
    debugPrint('[INSTRUMENTATION] RightStickSwipePad state created. State Hash: ${identityHashCode(this)}');
  }

  @override
  void dispose() {
    debugPrint('[INSTRUMENTATION] RightStickSwipePad state disposed. State Hash: ${identityHashCode(this)}');
    GamepadInputEngine.instance.releaseRightIfMatched(identityHashCode(this));
    _visualOffset.dispose();
    _active.dispose();
    _basePos.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    debugPrint('[INSTRUMENTATION] RightStickSwipePad pointer down. State Hash: ${identityHashCode(this)}, Position: ${event.position}, LocalPosition: ${renderBox.globalToLocal(event.position)}, Size: $size');

    if (widget.tapHapticsEnabled) {
      try {
        HapticsManager.instance.softTap();
      } catch (_) {}
    }

    GamepadInputEngine.instance.handleRightPointerDown(
      event: event,
      parentSize: size,
      layout: 'RS_SWIPE',
      config: widget.output.config,
      converter: (globalPos) {
        if (!mounted) return globalPos;
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box != null && box.attached) {
          return box.globalToLocal(globalPos);
        }
        return globalPos;
      },
      visualOffset: _visualOffset,
      active: _active,
      basePos: _basePos,
      controlId: 'RS-SWIPE_${identityHashCode(this)}',
      controlHashCode: identityHashCode(this),
      baseSize: 150.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      child: RepaintBoundary(
        child: ValueListenableBuilder<bool>(
          valueListenable: _active,
          builder: (context, active, child) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.highlightColor.withValues(alpha: 0.15)
                    : AppColors.backgroundColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppColors.highlightColor : AppColors.textPrimary,
                  width: AppColors.borderThickness,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.visibility_rounded,
                        size: 28,
                        color: active
                            ? AppColors.highlightColor
                            : AppColors.textPrimary.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                  Positioned(
                    left: 10,
                    child: Icon(
                      Icons.keyboard_arrow_left_rounded,
                      color: active
                          ? AppColors.highlightColor.withValues(alpha: 0.4)
                          : AppColors.textPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    child: Icon(
                      Icons.keyboard_arrow_right_rounded,
                      color: active
                          ? AppColors.highlightColor.withValues(alpha: 0.4)
                          : AppColors.textPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: active
                          ? AppColors.highlightColor.withValues(alpha: 0.4)
                          : AppColors.textPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: active
                          ? AppColors.highlightColor.withValues(alpha: 0.4)
                          : AppColors.textPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class RightStickFixedPreview extends StatelessWidget {
  const RightStickFixedPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final knobSize = size * 0.33;
        final borderRadius = size * 0.3;
        final borderWidth = size > 60 ? AppColors.borderThickness : 1.5;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundColor,
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: AppColors.textPrimary,
                      width: borderWidth,
                    ),
                  ),
                ),
                Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.lightColor,
                      width: borderWidth,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RightStickFloatingPreview extends StatelessWidget {
  final bool faded;

  const RightStickFloatingPreview({
    super.key,
    this.faded = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final symbolSize = size * 0.7;
        final knobSize = symbolSize * 0.33;
        final borderRadius = symbolSize * 0.3;
        final borderWidth = symbolSize > 60 ? AppColors.borderThickness : 1.5;

        return Center(
          child: Opacity(
            opacity: faded ? 0.35 : 1.0,
            child: SizedBox(
              width: symbolSize,
              height: symbolSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: symbolSize,
                    height: symbolSize,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundColor,
                      borderRadius: BorderRadius.circular(borderRadius),
                      border: Border.all(
                        color: AppColors.textPrimary,
                        width: borderWidth,
                      ),
                    ),
                  ),
                  Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.lightColor,
                        width: borderWidth,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class RightStickSwipePreview extends StatelessWidget {
  final bool active;

  const RightStickSwipePreview({
    super.key,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = active
        ? AppColors.highlightColor
        : AppColors.textPrimary.withValues(alpha: 0.6);
    final iconColor = active
        ? AppColors.highlightColor.withValues(alpha: 0.4)
        : AppColors.textPrimary.withValues(alpha: 0.2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final size = math.min(width, height);
        final iconSize = size > 80 ? 24.0 : 16.0;

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: active
                ? AppColors.highlightColor.withValues(alpha: 0.15)
                : AppColors.backgroundColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppColors.highlightColor : AppColors.textPrimary,
              width: AppColors.borderThickness,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.visibility_rounded,
                size: size > 80 ? 28.0 : 18.0,
                color: textColor,
              ),
              Positioned(
                left: size > 80 ? 10 : 4,
                child: Icon(
                  Icons.keyboard_arrow_left_rounded,
                  size: iconSize,
                  color: iconColor,
                ),
              ),
              Positioned(
                right: size > 80 ? 10 : 4,
                child: Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: iconSize,
                  color: iconColor,
                ),
              ),
              Positioned(
                top: size > 80 ? 10 : 4,
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: iconSize,
                  color: iconColor,
                ),
              ),
              Positioned(
                bottom: size > 80 ? 10 : 4,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: iconSize,
                  color: iconColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
