import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'juicy_widgets.dart';

typedef ButtonStateCallback = void Function(String state);

class ControlButton extends StatefulWidget {
  final String label;
  final ButtonStateCallback onStateChange;
  final double width;
  final double? height;
  final Widget? icon;
  final BorderRadiusGeometry? borderRadius;

  const ControlButton({
    super.key,
    required this.label,
    required this.onStateChange,
    this.width = 80,
    this.height,
    this.icon,
    this.borderRadius,
  });

  @override
  State<ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton> {
  @override
  Widget build(BuildContext context) {
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
    final height =
        widget.height ??
        (['SELECT', 'START'].contains(widget.label) ? 40.0 : 80.0);

    return SizedBox(
      width: widget.width,
      height: height,
      child: JuicyButton(
        onStateChange: widget.onStateChange,
        onTap: () {},
        backgroundColor: AppColors.backgroundColor,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
        borderThickness: 3,
        padding: EdgeInsets.zero,
        child: Center(
          child: widget.icon ??
              (showText
                  ? Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontFamily: 'momo',
                      ),
                    )
                  : const SizedBox.shrink()),
        ),
      ),
    );
  }
}
