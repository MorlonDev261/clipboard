import 'package:flutter/material.dart';

/// Dialog size policy, applied app-wide through the theme:
/// - phones (< 600 dp): about 92 % of the screen width,
/// - larger windows: at least 480 dp wide (never a tiny shrink-wrapped box).
ThemeData wideDialogTheme(BuildContext context) {
  final theme = Theme.of(context);
  final width = MediaQuery.sizeOf(context).width;
  const margin = 12.0;
  final phone = width < 600;
  final minWidth = phone ? width - margin * 2 : 480.0;
  return theme.copyWith(
    dialogTheme: theme.dialogTheme.copyWith(
      insetPadding: EdgeInsets.symmetric(
        horizontal: phone ? margin : 40,
        vertical: 24,
      ),
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: 560),
    ),
  );
}
