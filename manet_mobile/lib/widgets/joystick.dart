import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/gamepad_input_engine.dart';
import '../services/preferences_service.dart';

typedef StickCallback = void Function(double x, double y);

RenderBox? _getVirtualRoot(BuildContext context) {
  try {
    final overlay = Overlay.of(context);
    return overlay.context.findRenderObject() as RenderBox?;
  } catch (_) {
    return null;
  }
}

class Joystick extends StatefulWidget {
  final double size;
  final StickCallback onChanged;
  final VoidCallback onReleased;
  final double sensitivity;
  final bool isMini;

  const Joystick({
    super.key,
    required this.size,
    required this.onChanged,
    required this.onReleased,
    this.sensitivity = 1.0,
    this.isMini = false,
  });

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  final ValueNotifier<Offset> _visualOffset = ValueNotifier(Offset.zero);
  final ValueNotifier<bool> _active = ValueNotifier(false);
  final ValueNotifier<Offset> _basePos = ValueNotifier(Offset.zero);

  @override
  void initState() {
    super.initState();
    debugPrint('[INSTRUMENTATION] Joystick (fixed) state created. State Hash: ${identityHashCode(this)}');
  }

  @override
  void dispose() {
    debugPrint('[INSTRUMENTATION] Joystick (fixed) state disposed. State Hash: ${identityHashCode(this)}');
    GamepadInputEngine.instance.releaseLeftIfMatched(identityHashCode(this));
    _visualOffset.dispose();
    _active.dispose();
    _basePos.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    debugPrint('[INSTRUMENTATION] Joystick (fixed) pointer down. State Hash: ${identityHashCode(this)}, Position: ${event.position}, LocalPosition: ${renderBox.globalToLocal(event.position)}, Size: $size');

    GamepadInputEngine.instance.handleLeftPointerDown(
      event: event,
      parentSize: size,
      mode: MovementMode.fixedJoystick,
      sensitivity: widget.sensitivity,
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
      controlId: 'left_fixed_${identityHashCode(this)}',
      controlHashCode: identityHashCode(this),
      baseSize: widget.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final knobSize = widget.size > 100 ? 40.0 : widget.size * 0.33;
    final borderRadius = widget.size * 0.3;

    final stickWidget = SizedBox(
      width: widget.size,
      height: widget.size,
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
                      width: widget.size,
                      height: widget.size,
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
                    left: widget.size / 2 - knobSize / 2 + visualOffset.dx,
                    top: widget.size / 2 - knobSize / 2 + visualOffset.dy,
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
    );

    if (widget.isMini) {
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        child: stickWidget,
      );
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      child: RepaintBoundary(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.only(left: 24.0, bottom: 8.0),
          child: stickWidget,
        ),
      ),
    );
  }
}

class AdaptiveJoystick extends StatefulWidget {
  final StickCallback onChanged;
  final VoidCallback onReleased;
  final double sensitivity;

  const AdaptiveJoystick({
    super.key,
    required this.onChanged,
    required this.onReleased,
    this.sensitivity = 1.0,
  });

  @override
  State<AdaptiveJoystick> createState() => _AdaptiveJoystickState();
}

class _AdaptiveJoystickState extends State<AdaptiveJoystick>
    with TickerProviderStateMixin {
  late AnimationController _appearController;
  late AnimationController _resetController;
  Offset _resetStartPos = Offset.zero;
  Size _lastBounds = Size.zero;

  final ValueNotifier<Offset> _visualOffset = ValueNotifier(Offset.zero);
  final ValueNotifier<bool> _active = ValueNotifier(false);
  final ValueNotifier<Offset> _basePos = ValueNotifier(Offset.zero);

  static const double baseSize = 150.0;
  static const double stickSize = 50.0;

  @override
  void initState() {
    super.initState();
    debugPrint('[INSTRUMENTATION] AdaptiveJoystick (floating) state created. State Hash: ${identityHashCode(this)}');
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: 1.0,
    );
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _resetController.addListener(() {
      if (!mounted) return;
      if (_resetController.isAnimating) {
        final t = CurvedAnimation(
          parent: _resetController,
          curve: Curves.easeOutBack,
        ).value;
        final targetPos = Offset(_lastBounds.width / 2, _lastBounds.height * 0.7);
        _basePos.value = Offset.lerp(_resetStartPos, targetPos, t)!;
      }
    });
    _resetController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _basePos.value = Offset.zero;
      }
    });
    _active.addListener(_onActiveChanged);
  }

  @override
  void dispose() {
    debugPrint('[INSTRUMENTATION] AdaptiveJoystick (floating) state disposed. State Hash: ${identityHashCode(this)}');
    _active.removeListener(_onActiveChanged);
    GamepadInputEngine.instance.releaseLeftIfMatched(identityHashCode(this));
    _appearController.dispose();
    _resetController.dispose();
    _visualOffset.dispose();
    _active.dispose();
    _basePos.dispose();
    super.dispose();
  }

  void _onActiveChanged() {
    if (!mounted) return;
    if (_active.value) {
      _appearController.forward(from: 0.0);
      if (_resetController.isAnimating) {
        _resetController.stop();
      }
    } else {
      final x = _basePos.value.dx;
      final width = _lastBounds.width;
      if (width > 0 && (x < 0 || x > width)) {
        _resetStartPos = _basePos.value;
        _resetController.forward(from: 0.0);
      }
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

  void _handlePointerDown(PointerDownEvent event, Size bounds) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    debugPrint('[INSTRUMENTATION] AdaptiveJoystick (floating) pointer down. State Hash: ${identityHashCode(this)}, Position: ${event.position}, LocalPosition: ${renderBox.globalToLocal(event.position)}, Size: $size');

    GamepadInputEngine.instance.handleLeftPointerDown(
      event: event,
      parentSize: size,
      mode: MovementMode.floatingJoystick,
      sensitivity: widget.sensitivity,
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
      controlId: 'left_floating_${identityHashCode(this)}',
      controlHashCode: identityHashCode(this),
      baseSize: baseSize,
      clampBase: _clampBase,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        _lastBounds = bounds;

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _handlePointerDown(event, bounds),
          child: RepaintBoundary(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
              child: ValueListenableBuilder<bool>(
                valueListenable: _active,
                builder: (context, active, child) {
                  return ValueListenableBuilder<Offset>(
                    valueListenable: _basePos,
                    builder: (context, basePos, child) {
                      final effectiveBaseOffset = basePos == Offset.zero
                          ? Offset(bounds.width / 2, bounds.height * 0.7)
                          : basePos;

                      return ValueListenableBuilder<Offset>(
                        valueListenable: _visualOffset,
                        builder: (context, visualOffset, child) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: effectiveBaseOffset.dx - baseSize / 2,
                                top: effectiveBaseOffset.dy - baseSize / 2,
                                child: AnimatedBuilder(
                                  animation: _appearController,
                                  builder: (context, child) {
                                    final scale = (0.8 + (_appearController.value * 0.2)) * (active ? 0.92 : 1.0);
                                    final opacity = active
                                        ? 1.0
                                        : 0.2 + (_appearController.value * 0.8);

                                    return Transform.scale(
                                      scale: scale,
                                      child: Opacity(opacity: opacity, child: child),
                                    );
                                  },
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
                                          duration: active
                                              ? Duration.zero
                                              : const Duration(milliseconds: 300),
                                          curve: active ? Curves.linear : Curves.elasticOut,
                                          left: baseSize / 2 - stickSize / 2 + visualOffset.dx,
                                          top: baseSize / 2 - stickSize / 2 + visualOffset.dy,
                                          child: AnimatedScale(
                                            scale: active ? 1.25 : 1.0,
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
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
