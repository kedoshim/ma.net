import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// --- JOYSTICK BEHAVIOR CONFIGURATIONS ---
// If true, joystick output values (x, y) are restricted to a unit circle (magnitude <= 1.0).
// If false, values are clamped independently to [-1.0, 1.0] (allowing diagonals to reach 1.0, 1.0).
const bool kNormalizeJoystickInCircle = false;

// If true, the visual stick knob position is restricted to a circle.
// If false, the visual knob position is clamped to a square.
const bool kClampVisualKnobInCircle = true;

typedef StickCallback = void Function(double x, double y);

class Joystick extends StatefulWidget {
  final double size;
  final StickCallback onChanged;
  final VoidCallback onReleased;

  const Joystick({
    super.key,
    required this.size,
    required this.onChanged,
    required this.onReleased,
  });

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
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

      widget.onChanged(_currentX, _currentY);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _updateStick(Offset localPosition, Size bounds) {
    final center = Offset(24.0 + widget.size / 2, bounds.height - 8.0 - widget.size / 2);

    final dx = (localPosition.dx - center.dx) / (widget.size / 2);
    final dy = (localPosition.dy - center.dy) / (widget.size / 2);

    if (kNormalizeJoystickInCircle) {
      double distance = Offset(dx, dy).distance;
      double clampedDistance = distance.clamp(0.0, 1.0);
      final direction = Offset(dx, dy).direction;

      final clampedX = math.cos(direction) * clampedDistance;
      final clampedY = math.sin(direction) * clampedDistance;

      _currentX = clampedX;
      _currentY = -clampedY;
    } else {
      _currentX = dx.clamp(-1.0, 1.0);
      _currentY = -dy.clamp(-1.0, 1.0);
    }

    double visualX;
    double visualY;
    if (kClampVisualKnobInCircle) {
      double distance = Offset(dx, dy).distance;
      double clampedDistance = distance.clamp(0.0, 1.0);
      final direction = Offset(dx, dy).direction;
      visualX = math.cos(direction) * clampedDistance;
      visualY = math.sin(direction) * clampedDistance;
    } else {
      visualX = dx.clamp(-1.0, 1.0);
      visualY = dy.clamp(-1.0, 1.0);
    }

    setState(() {
      _stickOffset = Offset(
        visualX * (widget.size / 2 - 20),
        visualY * (widget.size / 2 - 20),
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

    widget.onReleased();
  }

  @override
  void dispose() {
    _stopHeartbeat();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event, Size bounds) {
    if (_pointerId != null) return;
    _pointerId = event.pointer;
    _active = true;
    _updateStick(event.localPosition, bounds);
    widget.onChanged(_currentX, _currentY);
    _startHeartbeat();
  }

  void _handlePointerMove(PointerMoveEvent event, Size bounds) {
    if (event.pointer != _pointerId) return;
    if (_active) {
      _updateStick(event.localPosition, bounds);
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
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _handlePointerDown(event, constraints.biggest),
          onPointerMove: (event) => _handlePointerMove(event, constraints.biggest),
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.only(left: 24.0, bottom: 8.0),
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: _active ? 0.92 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
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
                    left: widget.size / 2 - 20 + _stickOffset.dx,
                    top: widget.size / 2 - 20 + _stickOffset.dy,
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

class AdaptiveJoystick extends StatefulWidget {
  final StickCallback onChanged;
  final VoidCallback onReleased;

  const AdaptiveJoystick({
    super.key,
    required this.onChanged,
    required this.onReleased,
  });

  @override
  State<AdaptiveJoystick> createState() => _AdaptiveJoystickState();
}

class _AdaptiveJoystickState extends State<AdaptiveJoystick>
    with TickerProviderStateMixin {
  Offset? _baseOffset;
  Offset _stickOffset = Offset.zero;
  bool _active = false;
  int? _pointerId;

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
      value: 1.0,
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
      widget.onChanged(_currentX, _currentY);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _handlePointerDown(PointerDownEvent event, Size bounds) {
    if (_pointerId != null) return;
    _pointerId = event.pointer;
    _active = true;
    final touchPos = event.localPosition;

    _baseOffset = touchPos;
    _appearController.forward(from: 0.0);

    // Clamp the initial spawn position to ensure it stays within widget bounds
    double paddingX = baseSize / 2;
    double paddingY = baseSize / 2;
    _baseOffset = Offset(
      _baseOffset!.dx.clamp(paddingX, bounds.width - paddingX),
      _baseOffset!.dy.clamp(paddingY, bounds.height - paddingY),
    );

    _updateStick(touchPos, bounds);
    widget.onChanged(_currentX, _currentY);
    _startHeartbeat();
  }

  void _handlePointerMove(PointerMoveEvent event, Size bounds) {
    if (event.pointer != _pointerId) return;
    if (_active) {
      _updateStick(event.localPosition, bounds);
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

  void _updateStick(Offset touchPos, Size bounds) {
    if (_baseOffset == null) return;

    var delta = touchPos - _baseOffset!;
    double distance = delta.distance;
    final direction = delta.direction;

    // Drag the base along with the finger when reaching the limit
    if (distance > maxDistance) {
      Offset proposedBase =
          touchPos - Offset.fromDirection(direction, maxDistance);

      // Clamp base to securely stay within the left region bounds
      double paddingX = baseSize / 2;
      double paddingY = baseSize / 2;
      double clampedX = proposedBase.dx.clamp(
        paddingX,
        bounds.width - paddingX,
      );
      double clampedY = proposedBase.dy.clamp(
        paddingY,
        bounds.height - paddingY,
      );
      _baseOffset = Offset(clampedX, clampedY);

      // Recalculate delta using the clamped base offset
      delta = touchPos - _baseOffset!;
      distance = delta.distance;
    }

    if (kNormalizeJoystickInCircle) {
      final clampedDistance = distance.clamp(0.0, maxDistance);
      final clampedDelta = Offset.fromDirection(delta.direction, clampedDistance);

      final dx = clampedDelta.dx / maxDistance;
      final dy = clampedDelta.dy / maxDistance;

      _currentX = dx.clamp(-1.0, 1.0);
      _currentY = -dy.clamp(-1.0, 1.0);

      setState(() {
        _stickOffset = clampedDelta;
      });
    } else {
      final rawDx = delta.dx / maxDistance;
      final rawDy = delta.dy / maxDistance;

      _currentX = rawDx.clamp(-1.0, 1.0);
      _currentY = -rawDy.clamp(-1.0, 1.0);

      Offset visualDelta;
      if (kClampVisualKnobInCircle) {
        final clampedDistance = distance.clamp(0.0, maxDistance);
        visualDelta = Offset.fromDirection(delta.direction, clampedDistance);
      } else {
        visualDelta = Offset(
          rawDx.clamp(-1.0, 1.0) * maxDistance,
          rawDy.clamp(-1.0, 1.0) * maxDistance,
        );
      }

      setState(() {
        _stickOffset = visualDelta;
      });
    }
  }

  void _resetStick() {
    _stopHeartbeat();

    setState(() {
      _stickOffset = Offset.zero;
      _active = false;
      _currentX = 0;
      _currentY = 0;
      // Deliberately leave _baseOffset untouched so it stays faintly visible
    });

    widget.onReleased();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        final effectiveBaseOffset =
            _baseOffset ?? Offset(bounds.width / 2, bounds.height * 0.7);

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _handlePointerDown(event, bounds),
          onPointerMove: (event) => _handlePointerMove(event, bounds),
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: effectiveBaseOffset.dx - baseSize / 2,
                  top: effectiveBaseOffset.dy - baseSize / 2,
                  child: AnimatedBuilder(
                    animation: _appearController,
                    builder: (context, child) {
                      final scale = (0.8 + (_appearController.value * 0.2)) * (_active ? 0.92 : 1.0);
                      final opacity = _active
                          ? 0.8
                          : 0.2 + (_appearController.value * 0.2);

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
                            duration: _active
                                ? Duration.zero
                                : const Duration(milliseconds: 300),
                            curve: _active ? Curves.linear : Curves.elasticOut,
                            left:
                                baseSize / 2 - stickSize / 2 + _stickOffset.dx,
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
              ],
            ),
          ),
        );
      },
    );
  }
}
