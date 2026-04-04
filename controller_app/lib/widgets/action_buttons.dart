import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef ButtonStateCallback = void Function(String xinputId, String state);

class ActionButtons extends StatefulWidget {
  final Map<String, bool> visibleButtons;
  final ButtonStateCallback onButtonStateChanged;
  final bool editMode;

  const ActionButtons({
    super.key,
    required this.visibleButtons,
    required this.onButtonStateChanged,
    required this.editMode,
  });

  @override
  State<ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<ActionButtons> {
  late List<String> _buttonOrder;
  bool _isLoading = true;

  // Default button order
  static const List<String> _defaultButtonOrder = [
    'btnY',
    'btnB',
    'btnX',
    'btnA',
    'btnRB',
    'btnRT',
    'btnLB',
    'btnLT',
    'btnRS',
    'btnLS',
  ];

  @override
  void initState() {
    super.initState();
    _loadButtonOrder();
  }

  Future<void> _loadButtonOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList('buttonOrder');

      setState(() {
        _buttonOrder = savedOrder ?? _defaultButtonOrder.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _buttonOrder = _defaultButtonOrder.toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveButtonOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('buttonOrder', _buttonOrder);
    } catch (e) {
      debugPrint('Error saving button order: $e');
    }
  }

  void _reorderButtons(String draggedId, String targetId) {
    final draggedIndex = _buttonOrder.indexOf(draggedId);
    final targetIndex = _buttonOrder.indexOf(targetId);

    if (draggedIndex == -1 ||
        targetIndex == -1 ||
        draggedIndex == targetIndex) {
      return;
    }

    final item = _buttonOrder.removeAt(draggedIndex);
    _buttonOrder.insert(targetIndex, item);

    setState(() {});
    _saveButtonOrder();
  }

  List<String> _getVisibleButtons() {
    return _buttonOrder
        .where((btnId) => widget.visibleButtons[btnId] != false)
        .toList();
  }

  List<List<String>> _splitIntoColumns(List<String> buttons) {
    final left = <String>[];
    final right = <String>[];

    for (final button in buttons) {
      if (left.length <= right.length) {
        left.add(button);
      } else {
        right.add(button);
      }
    }

    // ensure the smaller column stays on the left
    if (left.length > right.length) {
      return [right, left];
    }

    return [left, right];
  }

  Widget _buildColumn(List<String> buttons) {
    return Expanded(
      child: Column(
        children: buttons
            .map(
              (btnId) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: widget.editMode
                      ? _buildEditModeButton(btnId)
                      : _buildGameButton(btnId),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildGameButton(String btnId) {
    final btnConfig = _getButtonConfig(btnId);

    return _GameButton(
      label: btnConfig.label,
      onStateChange: (state) =>
          widget.onButtonStateChanged(btnConfig.xinput, state),
    );
  }

  Widget _buildEditModeButton(String btnId) {
    final btnConfig = _getButtonConfig(btnId);

    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        if (details.data != btnId) {
          _reorderButtons(details.data, btnId);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDragTarget = candidateData.isNotEmpty;

        return LongPressDraggable<String>(
          data: btnId,
          feedback: SizedBox(
            width: 80,
            height: 80,
            child: Material(
              child: Opacity(
                opacity: 0.7,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(173, 216, 230, 1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    btnConfig.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: 'pico',
                    ),
                  ),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                btnConfig.label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontFamily: 'pico',
                ),
              ),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDragTarget
                  ? const Color.fromRGBO(144, 238, 144, 1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDragTarget ? Colors.green : Colors.black,
                width: isDragTarget ? 3 : 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              btnConfig.label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: 'pico',
              ),
            ),
          ),
        );
      },
    );
  }

  _ButtonConfig _getButtonConfig(String btnId) {
    const allButtons = [
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

    try {
      return allButtons.firstWhere((btn) => btn.id == btnId);
    } catch (e) {
      return const _ButtonConfig('unknown', '?', 'UNKNOWN');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final visible = _getVisibleButtons();
    if (visible.isEmpty) {
      return Center(
        child: Text(
          widget.editMode ? 'No buttons visible' : 'Enable buttons in options',
          style: const TextStyle(
            fontFamily: 'pico',
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
      );
    }

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

  const _ButtonConfig(this.id, this.label, this.xinput);
}

class _GameButton extends StatefulWidget {
  final String label;
  final void Function(String state) onStateChange;

  const _GameButton({required this.label, required this.onStateChange});

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
        ? const Color.fromARGB(255, 131, 194, 215)
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
