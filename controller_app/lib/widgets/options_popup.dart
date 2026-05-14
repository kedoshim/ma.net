import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class OptionsPopup extends StatefulWidget {
  final bool dpadMode;
  final ValueChanged<bool> onDpadModeChanged;
  final Map<String, bool> buttonVisibility;
  final ValueChanged<String> onButtonVisibilityChanged;
  final bool editMode;
  final ValueChanged<bool> onEditModeChanged;
  final ColorTheme currentTheme;
  final ValueChanged<ColorTheme> onThemeChanged;
  final VoidCallback? onRescanRequested;

  const OptionsPopup({
    super.key,
    required this.dpadMode,
    required this.onDpadModeChanged,
    required this.buttonVisibility,
    required this.onButtonVisibilityChanged,
    required this.editMode,
    required this.onEditModeChanged,
    required this.currentTheme,
    required this.onThemeChanged,
    this.onRescanRequested,
  });

  @override
  State<OptionsPopup> createState() => _OptionsPopupState();
}

class _OptionsPopupState extends State<OptionsPopup> {
  late bool _dpadMode;
  late bool _editMode;
  late ColorTheme _selectedTheme;

  @override
  void initState() {
    super.initState();
    _dpadMode = widget.dpadMode;
    _editMode = widget.editMode;
    _selectedTheme = widget.currentTheme;
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
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Options',
            style: TextStyle(
              fontFamily: 'pico',
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              minimumSize: const Size(40, 40),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'X',
              style: TextStyle(
                fontFamily: 'pico',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
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

            if (kIsWeb) ...[
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.android,
                  color: AppColors.textPrimary,
                ),
                title: const Text(
                  'Download Android App',
                  style: TextStyle(
                    fontFamily: 'pico',
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () async {
                  final url = Uri.base.resolve('/apk');
                  try {
                    await launchUrl(url, webOnlyWindowName: '_blank');
                  } catch (e) {
                    debugPrint('Could not launch download URL: $e');
                  }
                },
              ),
            ] else ...[
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.qr_code_scanner,
                  color: AppColors.textPrimary,
                ),
                title: const Text(
                  'Scan New Host',
                  style: TextStyle(
                    fontFamily: 'pico',
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onRescanRequested?.call();
                },
              ),
            ],
          ],
        ),
      ),
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
