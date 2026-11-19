import 'package:flutter/material.dart';

/// Colour tokens from docs/spec/theme.md, transcribed from the
/// "Color Codes (Hex Values)" panel in docs/design/style-guide.png.
///
/// Feature widgets use these names only - never a literal `Color(0x...)`.
class AppColors {
  const AppColors._();

  static const Color primaryGreen = Color(0xFF0B6623);
  static const Color headerGreen = Color(0xFF1B5E20);
  static const Color secondaryGreen = Color(0xFF2E7D32);
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color creamBackground = Color(0xFFFFF8E1);
  static const Color warmIvory = Color(0xFFFDF6E3);
  static const Color beige = Color(0xFFEAD7B7);
  static const Color golden = Color(0xFFF4B400);
  static const Color orange = Color(0xFFFB8C00);
  static const Color darkText = Color(0xFF1B1B1B);
  static const Color softText = Color(0xFF555555);
  static const Color expenseRed = Color(0xFFE53935);
  static const Color incomeGreen = Color(0xFF388E3C);
  static const Color navigationGrey = Color(0xFF9E9E9E);

  /// Semantic aliases used by the design system.
  static const Color buttonGreen = secondaryGreen;
  static const Color greenSuccess = incomeGreen;
  static const Color outline = beige;
  static const Color surface = warmIvory;
  static const Color onPrimary = Color(0xFFFFFFFF);
}
