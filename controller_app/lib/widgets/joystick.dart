import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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

  double _currentX = 0;
  double _currentY = 0;

  double _lastSentX = 0;
  double _lastSentY = 0;

  Timer? _heartbeatTimer;

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!_active) return;
      if (_currentX == _lastSentX && _currentY == _lastSentY) return;

      _lastSentX = _currentX;
      _lastSentY = _currentY;
      widget.onChanged(_currentX, _currentY);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _updateStick(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);

    final dx = (localPosition.dx - center.dx) / (widget.size / 2);
    final dy = (localPosition.dy - center.dy) / (widget.size / 2);

    final clampedX = dx.clamp(-1.0, 1.0);
    final clampedY = dy.clamp(-1.0, 1.0);

    _currentX = clampedX;
    _currentY = -clampedY;

    setState(() {
      _stickOffset = Offset(
        clampedX * (widget.size / 2 - 20),
        clampedY * (widget.size / 2 - 20),
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
      _lastSentX = 0;
      _lastSentY = 0;
    });

    widget.onReleased();
  }

  @override
  void dispose() {
    _stopHeartbeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          _active = true;
          _updateStick(details.localPosition);
          _lastSentX = _currentX;
          _lastSentY = _currentY;
          widget.onChanged(_currentX, _currentY);
          _startHeartbeat();
        },
        onPanUpdate: (details) {
          if (_active) {
            _updateStick(details.localPosition);
          }
        },
        onPanEnd: (_) => _resetStick(),
        onPanCancel: _resetStick,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
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
            Transform.translate(
              offset: _stickOffset,
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
          ],
        ),
      ),
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

  double _currentX = 0;
  double _currentY = 0;

  double _lastSentX = 0;
  double _lastSentY = 0;

  Timer? _heartbeatTimer;

  late AnimationController _appearController;

  static const double baseSize = 150.0;
  static const double stickSize = 50.0;
  static const double maxDistance = baseSize / 2;
  static const double jumpThreshold = 120.0;

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
      if (_currentX == _lastSentX && _currentY == _lastSentY) return;
      _lastSentX = _currentX;
      _lastSentY = _currentY;
      widget.onChanged(_currentX, _currentY);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _handlePanStart(DragStartDetails details, Size bounds) {
    _active = true;
    final touchPos = details.localPosition;

    if (_baseOffset == null) {
      _baseOffset = Offset(bounds.width / 2, bounds.height / 2);
    }

    final distance = (touchPos - _baseOffset!).distance;
    if (distance > jumpThreshold) {
      _baseOffset = touchPos;
      _appearController.forward(from: 0.0);
    }

    // Clamp the initial spawn position to ensure it stays within widget bounds
    double paddingX = baseSize / 2;
    double paddingY = baseSize / 2;
    _baseOffset = Offset(
      _baseOffset!.dx.clamp(paddingX, bounds.width - paddingX),
      _baseOffset!.dy.clamp(paddingY, bounds.height - paddingY),
    );

    _updateStick(touchPos, bounds);
    _lastSentX = _currentX;
    _lastSentY = _currentY;
    widget.onChanged(_currentX, _currentY);
    _startHeartbeat();
  }

  void _handlePanUpdate(DragUpdateDetails details, Size bounds) {
    if (_active) {
      _updateStick(details.localPosition, bounds);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _resetStick();
  }

  void _handlePanCancel() {
    _resetStick();
  }

  void _updateStick(Offset touchPos, Size bounds) {
    if (_baseOffset == null) return;

    var delta = touchPos - _baseOffset!;
    double distance = delta.distance;
    final direction = delta.direction;

    // Drag the base along with the finger when reaching the limit
    if (distance > maxDistance) {
      Offset proposedBase = touchPos - Offset.fromDirection(direction, maxDistance);

      // Clamp base to securely stay within the left region bounds
      double paddingX = baseSize / 2;
      double paddingY = baseSize / 2;
      double clampedX = proposedBase.dx.clamp(paddingX, bounds.width - paddingX);
      double clampedY = proposedBase.dy.clamp(paddingY, bounds.height - paddingY);
      _baseOffset = Offset(clampedX, clampedY);

      // Recalculate delta using the clamped base offset
      delta = touchPos - _baseOffset!;
      distance = delta.distance;
    }

    final clampedDistance = distance.clamp(0.0, maxDistance);
    final clampedDelta = Offset.fromDirection(delta.direction, clampedDistance);

    final dx = clampedDelta.dx / maxDistance;
    final dy = clampedDelta.dy / maxDistance;

    _currentX = dx.clamp(-1.0, 1.0);
    _currentY = -dy.clamp(-1.0, 1.0);

    setState(() {
      _stickOffset = clampedDelta;
    });
  }

  void _resetStick() {
    _stopHeartbeat();

    setState(() {
      _stickOffset = Offset.zero;
      _active = false;
      _currentX = 0;
      _currentY = 0;
      _lastSentX = 0;
      _lastSentY = 0;
      // Deliberately leave _baseOffset untouched so it stays faintly visible
    });

    widget.onReleased();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        final effectiveBaseOffset = _baseOffset ?? Offset(bounds.width / 2, bounds.height / 2);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _handlePanStart(d, bounds),
          onPanUpdate: (d) => _handlePanUpdate(d, bounds),
          onPanEnd: _handlePanEnd,
          onPanCancel: _handlePanCancel,
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
                      final scale = 0.8 + (_appearController.value * 0.2);
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
                            left: baseSize / 2 - stickSize / 2 + _stickOffset.dx,
                            top: baseSize / 2 - stickSize / 2 + _stickOffset.dy,
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
