import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/haptics_manager.dart';

class RightStickConfig {
  final double sensitivity;
  final bool invertX;
  final bool invertY;
  final double returnToCenterSpeed;
  final double deadzone;

  const RightStickConfig({
    this.sensitivity = 1.0,
    this.invertX = false,
    this.invertY = false,
    this.returnToCenterSpeed = 0.2,
    this.deadzone = 0.05,
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
    double x = rawX;
    double y = rawY;
    double magnitude = math.sqrt(x * x + y * y);
    if (magnitude < config.deadzone) {
      x = 0;
      y = 0;
    } else {
      double scaledMagnitude = (magnitude - config.deadzone) / (1.0 - config.deadzone);
      x = (x / magnitude) * scaledMagnitude;
      y = (y / magnitude) * scaledMagnitude;
    }

    x *= config.sensitivity;
    y *= config.sensitivity;

    x = x.clamp(-1.0, 1.0);
    y = y.clamp(-1.0, 1.0);

    if (config.invertX) x = -x;
    if (config.invertY) y = -y;

    onSendValue(x, y);
  }

  void release() {
    onReleased();
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
  bool _active = false;
  Offset? _baseOffset;
  Offset _stickOffset = Offset.zero;
  double _currentX = 0;
  double _currentY = 0;
  Timer? _heartbeatTimer;
  late AnimationController _appearController;

  static const double baseSize = 150.0;
  static const double stickSize = 50.0;
  static const double maxDistance = baseSize / 2;

  @override
  void initState() {
    super.initState();
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _stopHeartbeat();
    _appearController.dispose();
    super.dispose();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!_active) return;
      widget.output.processRawInput(_currentX, _currentY);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _resetStick() {
    _stopHeartbeat();
    widget.output.release();

    setState(() {
      _active = false;
      _currentX = 0;
      _currentY = 0;
      _stickOffset = Offset.zero;
    });

    _appearController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        final effectiveBaseOffset =
            _baseOffset ?? Offset(bounds.width / 2, bounds.height / 2);

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (widget.tapHapticsEnabled) {
              try {
                HapticsManager.instance.softTap();
              } catch (_) {}
            }

            final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
            final rootBox = _getVirtualRoot(context);
            Offset initialBase;

            if (renderBox != null && rootBox != null) {
              final touchPosOverlay = rootBox.globalToLocal(event.position);
              final double paddingX = baseSize / 2;
              final double paddingY = baseSize / 2;
              final clampedOverlay = Offset(
                touchPosOverlay.dx.clamp(paddingX, rootBox.size.width - paddingX),
                touchPosOverlay.dy.clamp(paddingY, rootBox.size.height - paddingY),
              );
              initialBase = renderBox.globalToLocal(rootBox.localToGlobal(clampedOverlay));
            } else {
              initialBase = event.localPosition;
            }

            setState(() {
              _active = true;
              _baseOffset = initialBase;
              _stickOffset = Offset.zero;
              _currentX = 0;
              _currentY = 0;
            });

            widget.output.processRawInput(0, 0);
            _startHeartbeat();
            _appearController.forward(from: 0.0);
          },
          onPointerMove: (event) {
            if (_active) {
              final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
              final rootBox = _getVirtualRoot(context);
              if (renderBox != null && rootBox != null) {
                final touchPosOverlay = rootBox.globalToLocal(event.position);
                final baseOffsetOverlay = rootBox.globalToLocal(renderBox.localToGlobal(_baseOffset!));

                var delta = touchPosOverlay - baseOffsetOverlay;
                double distance = delta.distance;
                final direction = delta.direction;

                if (distance > maxDistance) {
                  final proposedBaseOverlay =
                      touchPosOverlay - Offset.fromDirection(direction, maxDistance);
                  final double paddingX = baseSize / 2;
                  final double paddingY = baseSize / 2;
                  final clampedBaseOverlay = Offset(
                    proposedBaseOverlay.dx.clamp(paddingX, rootBox.size.width - paddingX),
                    proposedBaseOverlay.dy.clamp(paddingY, rootBox.size.height - paddingY),
                  );
                  _baseOffset = renderBox.globalToLocal(rootBox.localToGlobal(clampedBaseOverlay));

                  final updatedBaseOverlay = rootBox.globalToLocal(renderBox.localToGlobal(_baseOffset!));
                  delta = touchPosOverlay - updatedBaseOverlay;
                  distance = delta.distance;
                }

                final rawDx = delta.dx / maxDistance;
                final rawDy = delta.dy / maxDistance;
                _currentX = rawDx.clamp(-1.0, 1.0);
                _currentY = -rawDy.clamp(-1.0, 1.0);

                final clampedDistance = distance.clamp(0.0, maxDistance);
                final visualDelta = Offset.fromDirection(delta.direction, clampedDistance);

                setState(() {
                  _stickOffset = visualDelta;
                });
              } else if (renderBox != null) {
                final touchPos = event.localPosition;
                var delta = touchPos - _baseOffset!;
                double distance = delta.distance;
                final direction = delta.direction;

                if (distance > maxDistance) {
                  _baseOffset = touchPos - Offset.fromDirection(direction, maxDistance);
                  delta = touchPos - _baseOffset!;
                  distance = delta.distance;
                }

                final rawDx = delta.dx / maxDistance;
                final rawDy = delta.dy / maxDistance;
                _currentX = rawDx.clamp(-1.0, 1.0);
                _currentY = -rawDy.clamp(-1.0, 1.0);

                final clampedDistance = distance.clamp(0.0, maxDistance);
                final visualDelta = Offset.fromDirection(delta.direction, clampedDistance);

                setState(() {
                  _stickOffset = visualDelta;
                });
              }
            }
          },
          onPointerUp: (_) => _resetStick(),
          onPointerCancel: (_) => _resetStick(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Activation Cell (idle button state)
              RightStickFloatingPreview(faded: !_active),

              // Overlay Floating Joystick
              AnimatedBuilder(
                animation: _appearController,
                builder: (context, child) {
                  final showOverlay = _active || _appearController.value > 0;
                  if (!showOverlay) return const SizedBox.shrink();

                  final scale = (0.8 + (_appearController.value * 0.2)) *
                      (_active ? 0.92 : 1.0);
                  final opacity = _appearController.value * 0.8;

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
                              // Joystick Base
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
                              // Joystick Knob
                              AnimatedPositioned(
                                duration: _active
                                    ? Duration.zero
                                    : const Duration(milliseconds: 300),
                                curve: _active ? Curves.linear : Curves.elasticOut,
                                left: baseSize / 2 - stickSize / 2 + _stickOffset.dx,
                                top: baseSize / 2 - stickSize / 2 + _stickOffset.dy,
                                child: AnimatedScale(
                                  scale: _active ? 1.25 : 1.0,
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
              ),
            ],
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
  Offset _stickOffset = Offset.zero;
  bool _active = false;
  int? _pointerId;
  double _currentX = 0;
  double _currentY = 0;
  Timer? _heartbeatTimer;

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!_active) return;
      widget.output.processRawInput(_currentX, _currentY);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _updateStick(Offset localPosition, Size parentSize, double size) {
    final center = Offset(parentSize.width / 2, parentSize.height / 2);
    final dx = (localPosition.dx - center.dx) / (size / 2);
    final dy = (localPosition.dy - center.dy) / (size / 2);

    _currentX = dx.clamp(-1.0, 1.0);
    _currentY = -dy.clamp(-1.0, 1.0);

    double distance = Offset(dx, dy).distance;
    double clampedDistance = distance.clamp(0.0, 1.0);
    final direction = Offset(dx, dy).direction;

    double visualX = math.cos(direction) * clampedDistance;
    double visualY = math.sin(direction) * clampedDistance;

    setState(() {
      _stickOffset = Offset(
        visualX * (size / 2 - 20),
        visualY * (size / 2 - 20),
      );
    });
  }

  void _resetStick() {
    _stopHeartbeat();
    setState(() {
      _stickOffset = Offset.zero;
      _active = false;
      _currentX = 0;
      _currentY = 0;
    });
    widget.output.release();
  }

  @override
  void dispose() {
    _stopHeartbeat();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event, Size bounds, double size) {
    if (_pointerId != null) return;
    _pointerId = event.pointer;
    if (widget.tapHapticsEnabled) {
      HapticsManager.instance.softTap();
    }
    _active = true;
    _updateStick(event.localPosition, bounds, size);
    widget.output.processRawInput(_currentX, _currentY);
    _startHeartbeat();
  }

  void _handlePointerMove(PointerMoveEvent event, Size bounds, double size) {
    if (event.pointer != _pointerId) return;
    if (_active) {
      _updateStick(event.localPosition, bounds, size);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer == _pointerId) {
      _pointerId = null;
      _resetStick();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer == _pointerId) {
      _pointerId = null;
      _resetStick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _handlePointerDown(event, constraints.biggest, size),
          onPointerMove: (event) => _handlePointerMove(event, constraints.biggest, size),
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: _active ? 0.92 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundColor,
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: AppColors.textPrimary,
                          width: AppColors.borderThickness,
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: _active ? Duration.zero : const Duration(milliseconds: 300),
                    curve: _active ? Curves.linear : Curves.elasticOut,
                    left: size / 2 - 20 + _stickOffset.dx,
                    top: size / 2 - 20 + _stickOffset.dy,
                    child: AnimatedScale(
                      scale: _active ? 1.25 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 40,
                        height: 40,
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
  bool _active = false;
  Offset _lastTickPosition = Offset.zero;
  Offset _currentPosition = Offset.zero;
  bool _hasMovedThisTick = false;
  double _stickX = 0.0;
  double _stickY = 0.0;
  Timer? _tickTimer;

  void _startTimer() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!_active) return;

      if (_hasMovedThisTick) {
        final delta = _currentPosition - _lastTickPosition;
        const double fullDeflectionDelta = 25.0;

        double targetX = (delta.dx / fullDeflectionDelta).clamp(-1.0, 1.0);
        double targetY = (-delta.dy / fullDeflectionDelta).clamp(-1.0, 1.0);

        _stickX = targetX;
        _stickY = targetY;

        _lastTickPosition = _currentPosition;
        _hasMovedThisTick = false;
      } else {
        final decay = widget.output.config.returnToCenterSpeed;
        _stickX = _stickX * (1.0 - decay);
        _stickY = _stickY * (1.0 - decay);
        _lastTickPosition = _currentPosition;
      }

      widget.output.processRawInput(_stickX, _stickY);
    });
  }

  void _stopTimer() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  void _handlePanDown(DragDownDetails details) {
    if (widget.tapHapticsEnabled) {
      try {
        HapticsManager.instance.softTap();
      } catch (_) {}
    }
    setState(() {
      _active = true;
      _lastTickPosition = details.localPosition;
      _currentPosition = details.localPosition;
      _hasMovedThisTick = false;
      _stickX = 0.0;
      _stickY = 0.0;
    });
    widget.output.processRawInput(0, 0);
    _startTimer();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_active) {
      _currentPosition = details.localPosition;
      _hasMovedThisTick = true;
    }
  }

  void _handlePanEnd() {
    _stopTimer();
    setState(() {
      _active = false;
      _stickX = 0.0;
      _stickY = 0.0;
    });
    widget.output.release();
  }

  void _handlePanCancel() {
    _handlePanEnd();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: _handlePanDown,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: (_) => _handlePanEnd(),
      onPanCancel: _handlePanCancel,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: _active
              ? AppColors.highlightColor.withValues(alpha: 0.15)
              : AppColors.backgroundColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _active ? AppColors.highlightColor : AppColors.textPrimary,
            width: AppColors.borderThickness,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SWIPE PAD',
                  style: TextStyle(
                    fontFamily: 'momo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _active
                        ? AppColors.highlightColor
                        : AppColors.textPrimary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 10,
              child: Icon(
                Icons.keyboard_arrow_left_rounded,
                color: _active
                    ? AppColors.highlightColor.withValues(alpha: 0.4)
                    : AppColors.textPrimary.withValues(alpha: 0.2),
              ),
            ),
            Positioned(
              right: 10,
              child: Icon(
                Icons.keyboard_arrow_right_rounded,
                color: _active
                    ? AppColors.highlightColor.withValues(alpha: 0.4)
                    : AppColors.textPrimary.withValues(alpha: 0.2),
              ),
            ),
            Positioned(
              top: 10,
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                color: _active
                    ? AppColors.highlightColor.withValues(alpha: 0.4)
                    : AppColors.textPrimary.withValues(alpha: 0.2),
              ),
            ),
            Positioned(
              bottom: 10,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _active
                    ? AppColors.highlightColor.withValues(alpha: 0.4)
                    : AppColors.textPrimary.withValues(alpha: 0.2),
              ),
            ),
          ],
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
        final opacity = faded ? 0.3 : 1.0;
        final borderWidth = symbolSize > 60 ? AppColors.borderThickness : 1.5;

        return Center(
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
                    color: AppColors.backgroundColor.withValues(alpha: opacity * 0.15),
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: AppColors.textPrimary.withValues(alpha: opacity),
                      width: borderWidth,
                    ),
                  ),
                ),
                Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: opacity),
                    shape: BoxShape.circle,
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
        final fontSize = size > 80 ? 14.0 : 10.0;
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
              Text(
                'SWIPE PAD',
                style: TextStyle(
                  fontFamily: 'momo',
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
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
