import 'package:flutter/material.dart';
import '../services/sound_effect_service.dart';
import '../theme/app_colors.dart';

class ServerOptionsPopup extends StatefulWidget {
  final ColorTheme currentTheme;
  final ValueChanged<ColorTheme> onThemeChanged;

  const ServerOptionsPopup({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<ServerOptionsPopup> createState() => _ServerOptionsPopupState();
}

class _ServerOptionsPopupState extends State<ServerOptionsPopup> {
  late ColorTheme _selectedTheme;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentTheme;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.screenBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: AppColors.textPrimary,
          width: AppColors.borderThickness,
        ),
      ),
      title: Row(
        children: [
          const Text(
            'Opcoes',
            style: TextStyle(
              fontFamily: 'pico',
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cores do ma.net',
            style: TextStyle(
              fontFamily: 'pico',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(ColorTheme.values.length, (index) {
              final theme = ColorTheme.values[index];
              final themeColor = AppColors.getTheme(theme);
              final isSelected = _selectedTheme == theme;

              return GestureDetector(
                onTap: () {
                  SoundEffectService.instance.playThemeSelect();
                  setState(() => _selectedTheme = theme);
                  AppColors.setTheme(theme);
                  widget.onThemeChanged(theme);
                },
                child: Container(
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
              );
            }),
          ),
        ],
      ),
    );
  }
}
