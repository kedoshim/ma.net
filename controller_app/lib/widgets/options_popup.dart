import 'package:flutter/material.dart';

class OptionsPopup extends StatefulWidget {
  final bool dpadMode;
  final ValueChanged<bool> onDpadModeChanged;
  final Map<String, bool> buttonVisibility;
  final ValueChanged<String> onButtonVisibilityChanged;

  const OptionsPopup({
    super.key,
    required this.dpadMode,
    required this.onDpadModeChanged,
    required this.buttonVisibility,
    required this.onButtonVisibilityChanged,
  });

  @override
  State<OptionsPopup> createState() => _OptionsPopupState();
}

class _OptionsPopupState extends State<OptionsPopup> {
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
              value: widget.dpadMode,
              onChanged: (value) {
                widget.onDpadModeChanged(value);
                setState(() {});
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
