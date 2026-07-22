import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFF0A0A0C);
  static const surface = Color(0xFF17171B);
  static const surfaceElevated = Color(0xFF1F1F24);
  static const border = Color(0xFF2A2A31);

  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9A9AA5);
  static const textMuted = Color(0xFF6B6B75);

  static const accentBlue = Color(0xFF4A8FFF);
  static const green = Color(0xFF34D399);
  static const orange = Color(0xFFFB923C);
  static const red = Color(0xFFF87171);

  /// Green when [ratio] (spent/budget) is comfortably under, orange approaching, red over.
  static Color budgetColor(double ratio) {
    if (ratio >= 1.0) return red;
    if (ratio >= 0.75) return orange;
    return green;
  }
}
