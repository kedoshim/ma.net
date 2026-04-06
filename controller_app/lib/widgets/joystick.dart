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

  Timer? _heartbeatTimer;

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) {
        if (!_active) return;

        widget.onChanged(_currentX, _currentY);
      },
    );
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

    widget.onChanged(_currentX, _currentY);
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