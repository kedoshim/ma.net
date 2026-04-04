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

  void _updateStick(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final dx = (localPosition.dx - center.dx) / (widget.size / 2);
    final dy = (localPosition.dy - center.dy) / (widget.size / 2);
    final clampedX = dx.clamp(-1.0, 1.0);
    final clampedY = dy.clamp(-1.0, 1.0);

    setState(() {
      _stickOffset = Offset(
        clampedX * (widget.size / 2 - 20),
        clampedY * (widget.size / 2 - 20),
      );
    });

    widget.onChanged(clampedX, -clampedY);
  }

  void _resetStick() {
    setState(() {
      _stickOffset = Offset.zero;
      _active = false;
    });
    widget.onReleased();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        onPanStart: (details) {
          _active = true;
          _updateStick(details.localPosition);
        },
        onPanUpdate: (details) {
          if (_active) _updateStick(details.localPosition);
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
