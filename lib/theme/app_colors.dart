import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFF0A1712);
  static const surface = Color(0xFF12251C);
  static const surfaceElevated = Color(0xFF183024);
  static const border = Color(0xFF244436);

  static const textPrimary = Color(0xFFF5F7F5);
  static const textSecondary = Color(0xFFA3B3AA);
  static const textMuted = Color(0xFF6E8377);

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
