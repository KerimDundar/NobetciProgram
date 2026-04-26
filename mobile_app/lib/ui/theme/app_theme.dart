import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color seedBlue = Color(0xFF2563EB);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFDC2626);
  static const double pagePadding = 16;
  static const double sectionGap = 12;
  static const double cardRadius = 8;

  static ThemeData build() {
    final colorScheme = ColorScheme.fromSeed(seedColor: seedBlue);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: VisualDensity.standard,
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        selectedColor: colorScheme.secondaryContainer,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
