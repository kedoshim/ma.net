import 'package:flutter/material.dart';

enum ColorTheme { blue, red, green, yellow }

class ThemeColors {
  final Color background;
  final Color highlight;

  const ThemeColors({required this.background, required this.highlight});
}

/// Central color configuration for the entire app
class AppColors {
  // Primary colors
  static const Color lightColor = Colors.white;
  static Color highlightColor = _themes[ColorTheme.blue]!.highlight;
  static Color backgroundColor = Colors.transparent;
  static Color screenBackground = _themes[ColorTheme.blue]!.background;

  // UI colors
  static const Color textPrimary = Color.fromRGBO(34, 34, 34, 1);

  // Interactive colors
  static const Color switchActiveThumb = Color.fromARGB(139, 187, 206, 255);
  static const Color dragTargetGreen = Color.fromRGBO(144, 238, 144, 1);
  static const Color greyDisabled = Color.fromARGB(255, 200, 200, 200);

  // Design system
  static const double borderThickness = 3.0;

  // Theme definitions: Pastel backgrounds with candy-colored complements
  static const Map<ColorTheme, ThemeColors> _themes = {
    ColorTheme.blue: ThemeColors(
      background: Color.fromARGB(255, 230, 245, 255), // Pastel blue
      highlight: Color.fromARGB(255, 234, 207, 153), // Candy orange
    ),
    ColorTheme.red: ThemeColors(
      background: Color.fromARGB(255, 255, 230, 241), // Pastel red
      highlight: Color.fromARGB(255, 141, 220, 220), // Candy cyan
    ),
    ColorTheme.green: ThemeColors(
      background: Color.fromARGB(255, 230, 255, 240), // Pastel green
      highlight: Color.fromARGB(255, 217, 133, 217), // Candy magenta
    ),
    ColorTheme.yellow: ThemeColors(
      background: Color.fromARGB(255, 255, 255, 230), // Pastel yellow
      highlight: Color.fromARGB(255, 175, 139, 210), // Candy purple
    ),
  };

  static void setTheme(ColorTheme theme) {
    final themeColors = _themes[theme];
    if (themeColors != null) {
      highlightColor = themeColors.highlight;
      screenBackground = themeColors.background;
    }
  }

  static ThemeColors getTheme(ColorTheme theme) => _themes[theme]!;
}
