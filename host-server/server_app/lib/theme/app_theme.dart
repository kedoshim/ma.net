import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBackground = Color.fromARGB(255, 255, 212, 212);
  static const Color primaryText = Colors.black;
  static const Color secondaryText = Colors.grey;
  static const Color info = Colors.blue; // Assuming info is blue

  static TextStyle titleLarge = const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: primaryText,
  );

  static TextStyle titleSmall = const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: primaryText,
  );

  static TextStyle bodyMedium = const TextStyle(
    fontSize: 16,
    color: primaryText,
  );

  static ThemeData get theme => ThemeData(
    primaryColor: primaryText,
    scaffoldBackgroundColor: primaryBackground,
    textTheme: TextTheme(
      titleLarge: titleLarge,
      titleSmall: titleSmall,
      bodyMedium: bodyMedium,
    ),
  );
}
