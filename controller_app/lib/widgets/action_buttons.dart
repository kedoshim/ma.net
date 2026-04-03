import 'package:flutter/material.dart';

typedef ButtonStateCallback = void Function(String xinputId, String state);

class ActionButtons extends StatelessWidget {
  final Map<String, bool> visibleButtons;
  final ButtonStateCallback onButtonStateChanged;

  const ActionButtons({
    super.key,
    required this.visibleButtons,
    required this.onButtonStateChanged,
  });

  List<_ButtonConfig> _getVisibleButtons() {
    final allButtons = [
      _ButtonConfig('btnY', 'Y', 'Y'),
      _ButtonConfig('btnB', 'B', 'B'),
      _ButtonConfig('btnX', 'X', 'X'),
      _ButtonConfig('btnA', 'A', 'A'),
      _ButtonConfig('btnRB', 'RB', 'RB'),
      _ButtonConfig('btnRT', 'RT', 'RT'),
      _ButtonConfig('btnLB', 'LB', 'LB'),
      _ButtonConfig('btnLT', 'LT', 'LT'),
      _ButtonConfig('btnRS', 'RS', 'RS'),
      _ButtonConfig('btnLS', 'LS', 'LS'),
    ];

    return allButtons
        .where((btn) => visibleButtons[btn.id] != false)
        .toList();
  }

  List<List<_ButtonConfig>> _splitIntoColumns(List<_ButtonConfig> buttons) {
    final left = <_ButtonConfig>[];
    final right = <_ButtonConfig>[];

    for (final button in buttons) {
      if (left.length <= right.length) {
        left.add(button);
      } else {
        right.add(button);
      }
    }

    // garante que a coluna menor fique na esquerda
    if (left.length > right.length) {
      return [right, left];
    }

    return [left, right];
  }

  Widget _buildColumn(List<_ButtonConfig> buttons) {
    return Expanded(
      child: Column(
        children: buttons
            .map(
              (btn) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _GameButton(
                    label: btn.label,
                    onStateChange: (state) =>
                        onButtonStateChanged(btn.xinput, state),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _getVisibleButtons();
    final columns = _splitIntoColumns(visible);

    return Row(
      children: [
        _buildColumn(columns[0]),
        const SizedBox(width: 8),
        _buildColumn(columns[1]),
      ],
    );
  }
}

class _ButtonConfig {
  final String id;
  final String label;
  final String xinput;

  _ButtonConfig(this.id, this.label, this.xinput);
}

class _GameButton extends StatefulWidget {
  final String label;
  final void Function(String state) onStateChange;

  const _GameButton({
    required this.label,
    required this.onStateChange,
  });

  @override
  State<_GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<_GameButton> {
  bool _hovered = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final background = (_hovered || _pressed)
        ? const Color.fromRGBO(173, 216, 230, 1)
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTapDown: (_) {
          _setPressed(true);
          widget.onStateChange('down');
        },
        onTapUp: (_) {
          _setPressed(false);
          widget.onStateChange('up');
        },
        onTapCancel: () {
          _setPressed(false);
          widget.onStateChange('up');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'pico',
            ),
          ),
        ),
      ),
    );
  }
}