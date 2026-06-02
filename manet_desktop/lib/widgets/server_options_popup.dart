import 'package:flutter/material.dart';
import '../services/sound_effect_service.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
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

  Widget _buildLanguageButton(BuildContext context, Locale locale, String label) {
    final isSelected = context.currentLocale.languageCode == locale.languageCode;
    return JuicyCard(
      isSelected: isSelected,
      selectedColor: AppColors.highlightColor,
      backgroundColor: AppColors.lightColor,
      borderRadius: 12,
      borderThickness: 3.0,
      onTap: () {
        SoundEffectService.instance.playThemeSelect();
        context.setLocale(locale);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'momo',
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return JuicyDialog(
      title: context.l10n.settings.title,
      maxWidth: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.settings.colorsTitle,
            style: const TextStyle(
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
          Text(
            context.l10n.settings.timeoutTitle,
            style: const TextStyle(
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
                    label: context.l10n.settings.timeoutValue(_selectedTimeoutMinutes),
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
                    context.l10n.settings.timeoutValue(_selectedTimeoutMinutes),
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
          const SizedBox(height: 24),
          Text(
            context.l10n.settings.languageTitle,
            style: const TextStyle(
              fontFamily: 'momo',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildLanguageButton(context, const Locale('pt', 'BR'), 'Português'),
              const SizedBox(width: 16),
              _buildLanguageButton(context, const Locale('en', 'US'), 'English'),
            ],
          ),
        ],
      ),
    );
  }
}
