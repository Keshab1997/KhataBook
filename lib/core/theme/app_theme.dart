// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The light, paper-and-forest-green design system from docs/spec/theme.md.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      brightness: Brightness.light,
      primary: AppColors.primaryGreen,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondaryGreen,
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
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.warmIvory,
        indicatorColor: AppColors.lightGreen,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 74,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppColors.primaryGreen : AppColors.softText,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primaryGreen : AppColors.navigationGrey,
            size: 22,
          );
        }),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.darkText, fontSize: 14),
        bodySmall: TextStyle(
          color: AppColors.softText,
          fontSize: 12,
          height: 1.3,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: AppColors.primaryGreen),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
    );
  }
}
