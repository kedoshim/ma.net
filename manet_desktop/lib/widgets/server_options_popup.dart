import 'package:flutter/material.dart';
import '../services/sound_effect_service.dart';
import '../theme/app_colors.dart';
import 'juicy_widgets.dart';

class ServerOptionsPopup extends StatefulWidget {
  final ColorTheme currentTheme;
  final ValueChanged<ColorTheme> onThemeChanged;
  final int currentTimeoutMinutes;
  final ValueChanged<int> onTimeoutChanged;

  const ServerOptionsPopup({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
    required this.currentTimeoutMinutes,
    required this.onTimeoutChanged,
  });

  @override
  State<ServerOptionsPopup> createState() => _ServerOptionsPopupState();
}

class _ServerOptionsPopupState extends State<ServerOptionsPopup> {
  late ColorTheme _selectedTheme;
  late int _selectedTimeoutMinutes;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentTheme;
    _selectedTimeoutMinutes = widget.currentTimeoutMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return JuicyDialog(
      title: 'Opções',
      maxWidth: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cores do ma.net',
            style: TextStyle(
              fontFamily: 'momo',
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

              return JuicyCard(
                isSelected: isSelected,
                selectedColor: themeColor.highlight,
                backgroundColor: themeColor.background,
                borderRadius: 12,
                borderThickness: 3.0,
                onTap: () {
                  SoundEffectService.instance.playThemeSelect();
                  setState(() => _selectedTheme = theme);
                  AppColors.setTheme(theme);
                  widget.onThemeChanged(theme);
                },
                child: const SizedBox(
                  width: 50,
                  height: 50,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tempo de reserva para jogadores desconectados',
            style: TextStyle(
              fontFamily: 'momo',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.highlightColor,
                    inactiveTrackColor: AppColors.greyDisabled.withValues(alpha: 0.3),
                    thumbColor: AppColors.highlightColor,
                    overlayColor: AppColors.highlightColor.withValues(alpha: 0.2),
                    valueIndicatorColor: AppColors.textPrimary,
                    valueIndicatorTextStyle: const TextStyle(
                      fontFamily: 'momo',
                      color: Colors.white,
                    ),
                  ),
                  child: Slider(
                    value: _selectedTimeoutMinutes.toDouble(),
                    min: 1,
                    max: 15,
                    divisions: 14,
                    label: '$_selectedTimeoutMinutes min',
                    onChanged: (value) {
                      setState(() {
                        _selectedTimeoutMinutes = value.toInt();
                      });
                      widget.onTimeoutChanged(_selectedTimeoutMinutes);
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                child: Center(
                  child: Text(
                    '$_selectedTimeoutMinutes min',
                    style: const TextStyle(
                      fontFamily: 'momo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
