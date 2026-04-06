import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

typedef ButtonStateCallback = void Function(String state);

class ControlButton extends StatefulWidget {
  final String label;
  final ButtonStateCallback onStateChange;

  const ControlButton({
    super.key,
    required this.label,
    required this.onStateChange,
  });

  @override
  State<ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final background = (_hovered || _pressed)
        ? AppColors.highlightColor
        : AppColors.backgroundColor;

    // Don't show text for directional buttons and select/start
    final showText = ![
      'UP',
      'DOWN',
      'LEFT',
      'RIGHT',
      'SELECT',
      'START',
    ].contains(widget.label);

    // Make SELECT and START shorter
    final height = ['SELECT', 'START'].contains(widget.label) ? 40.0 : 80.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _pressed = true);
          widget.onStateChange('down');
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onStateChange('up');
        },
        onTapCancel: () {
          setState(() => _pressed = false);
          widget.onStateChange('up');
        },
        child: Container(
          width: 80,
          height: height,
          alignment: Alignment.center,
          // margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.textPrimary,
              width: AppColors.borderThickness,
            ),
          ),
          child: showText
              ? Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'pico',
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
