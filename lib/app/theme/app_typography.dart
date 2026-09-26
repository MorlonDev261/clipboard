import 'package:flutter/material.dart';

/// Typography helpers for Clipboard.
///
/// The MVP relies on the default Material 3 type scale; this class centralises
/// tweaks so that swapping in a custom font later touches a single file.
abstract final class AppTypography {
  static TextTheme textTheme(TextTheme base) {
    return base.copyWith(
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
