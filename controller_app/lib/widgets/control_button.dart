import 'package:flutter/material.dart';

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
        ? const Color.fromRGBO(173, 216, 230, 0.25)
        : Colors.transparent;

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
    final height = ['SELECT', 'START'].contains(widget.label) ? 40.0 : 70.0;

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
          width: 70,
          height: height,
          alignment: Alignment.center,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: showText
              ? Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'pico',
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
