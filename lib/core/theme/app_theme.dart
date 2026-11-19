import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The light theme from docs/spec/theme.md. Dark theme is out of scope for v1.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      brightness: Brightness.light,
      primary: AppColors.primaryGreen,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.darkText,
      error: AppColors.expenseRed,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.creamBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.headerGreen,
        foregroundColor: AppColors.onPrimary,
        centerTitle: false,
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.warmIvory,
        indicatorColor: AppColors.lightGreen,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.darkText, fontSize: 14),
        bodySmall: TextStyle(color: AppColors.softText, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
    );
  }
}
