import 'package:flutter/material.dart';

/// Brand palette for Clipboard, following the suggested design tokens.
///
/// Colors are exposed as raw tokens here; [AppTheme] wires them into the
/// Material 3 [ColorScheme].
abstract final class AppColors {
  // Brand blue, sampled from the app logo (the hexagon).
  static const Color primary = Color(0xFF204DA0);
  static const Color secondary = Color(0xFF3B6FD6);

  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF0F172A);

  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E293B);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
}
