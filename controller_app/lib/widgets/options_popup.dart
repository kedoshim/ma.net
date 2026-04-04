import 'package:flutter/material.dart';

class OptionsPopup extends StatefulWidget {
  final bool dpadMode;
  final ValueChanged<bool> onDpadModeChanged;
  final Map<String, bool> buttonVisibility;
  final ValueChanged<String> onButtonVisibilityChanged;
  final bool editMode;
  final ValueChanged<bool> onEditModeChanged;

  const OptionsPopup({
    super.key,
    required this.dpadMode,
    required this.onDpadModeChanged,
    required this.buttonVisibility,
    required this.onButtonVisibilityChanged,
    required this.editMode,
    required this.onEditModeChanged,
  });

  @override
  State<OptionsPopup> createState() => _OptionsPopupState();
}

class _OptionsPopupState extends State<OptionsPopup> {
  late bool _dpadMode;
  late bool _editMode;

  @override
  void initState() {
    super.initState();
    _dpadMode = widget.dpadMode;
    _editMode = widget.editMode;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFF3E5C8),
      title: const Text(
        'Options',
        style: TextStyle(fontFamily: 'pico', fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // D-Pad Toggle
            SwitchListTile(
              title: const Text(
                'D-Pad Mode',
                style: TextStyle(fontFamily: 'pico'),
              ),
              value: _dpadMode,
              onChanged: (value) {
                setState(() => _dpadMode = value);
                widget.onDpadModeChanged(value);
              },
              activeThumbColor: const Color.fromARGB(139, 187, 206, 255),
              activeTrackColor: Colors.lightBlue.shade100,
            ),
            const Divider(),
            // Edit Mode Toggle
            SwitchListTile(
              title: const Text(
                'Edit Mode',
                style: TextStyle(fontFamily: 'pico'),
              ),
              subtitle: const Text(
                'Reorder buttons by dragging',
                style: TextStyle(fontFamily: 'pico', fontSize: 12),
              ),
              value: _editMode,
              onChanged: (value) {
                setState(() => _editMode = value);
                widget.onEditModeChanged(value);
              },
              activeThumbColor: const Color.fromARGB(139, 187, 206, 255),
              activeTrackColor: Colors.lightBlue.shade100,
            ),
            const Divider(),
            const Text(
              'Action Buttons',
              style: TextStyle(
                fontFamily: 'pico',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            // Action Button Toggles
            ..._buildButtonToggles(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(fontFamily: 'pico')),
        ),
      ],
    );
  }

  List<Widget> _buildButtonToggles() {
    const buttons = ['A', 'B', 'X', 'Y', 'RB', 'RT', 'RS', 'LB', 'LT', 'LS'];

    return buttons.map((button) {
      final buttonKey = 'btn$button';
      return SwitchListTile(
        title: Text(button, style: const TextStyle(fontFamily: 'pico')),
        value: widget.buttonVisibility[buttonKey] ?? true,
        onChanged: (value) {
          widget.onButtonVisibilityChanged(buttonKey);
          setState(() {});
        },
        dense: true,
        activeThumbColor: const Color.fromARGB(139, 187, 206, 255),
        activeTrackColor: Colors.lightBlue.shade100,
      );
    }).toList();
  }
}
