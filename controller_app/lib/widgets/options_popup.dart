import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

class OptionsPopup extends StatefulWidget {
  final bool dpadMode;
  final ValueChanged<bool> onDpadModeChanged;
  final Map<String, bool> buttonVisibility;
  final ValueChanged<String> onButtonVisibilityChanged;
  final bool editMode;
  final ValueChanged<bool> onEditModeChanged;
  final ValueChanged<ColorTheme> onThemeChanged;

  const OptionsPopup({
    super.key,
    required this.dpadMode,
    required this.onDpadModeChanged,
    required this.buttonVisibility,
    required this.onButtonVisibilityChanged,
    required this.editMode,
    required this.onEditModeChanged,
    required this.onThemeChanged,
  });

  @override
  State<OptionsPopup> createState() => _OptionsPopupState();
}

class _OptionsPopupState extends State<OptionsPopup> {
  late bool _dpadMode;
  late bool _editMode;
  ColorTheme _selectedTheme = ColorTheme.blue;

  @override
  void initState() {
    super.initState();
    _dpadMode = widget.dpadMode;
    _editMode = widget.editMode;
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt('selectedTheme') ?? 0;
      setState(() {
        _selectedTheme = ColorTheme.values[themeIndex];
      });
    } catch (e) {
      setState(() {
        _selectedTheme = ColorTheme.blue;
      });
    }
  }

  Future<void> _saveTheme(ColorTheme theme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selectedTheme', theme.index);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.screenBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.textPrimary,
          width: AppColors.borderThickness,
        ),
      ),
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
              activeThumbColor: AppColors.switchActiveThumb,
              activeTrackColor: AppColors.highlightColor,
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
              activeThumbColor: AppColors.switchActiveThumb,
              activeTrackColor: AppColors.highlightColor,
            ),
            const Divider(),
            const Text(
              'Color Theme',
              style: TextStyle(
                fontFamily: 'pico',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            _buildThemeSelector(),
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
        activeThumbColor: AppColors.switchActiveThumb,
        activeTrackColor: AppColors.highlightColor,
      );
    }).toList();
  }

  Widget _buildThemeSelector() {
    final themes = ColorTheme.values;
    final themeNames = ['Blue', 'Red', 'Green', 'Yellow'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(themes.length, (index) {
        final theme = themes[index];
        final themeColor = AppColors.getTheme(theme);
        final isSelected = _selectedTheme == theme;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTheme = theme;
            });
            AppColors.setTheme(theme);
            _saveTheme(theme);
            widget.onThemeChanged(theme);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: themeColor.background,
                  border: Border.all(
                    color: AppColors.textPrimary,
                    width: isSelected ? 3 : AppColors.borderThickness,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                themeNames[index],
                style: const TextStyle(fontFamily: 'pico', fontSize: 12),
              ),
            ],
          ),
        );
      }),
    );
  }
}
