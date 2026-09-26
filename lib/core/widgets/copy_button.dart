import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';

/// Copies [text] to the system clipboard and shows a confirmation snackbar.
///
/// Uses the native clipboard via [Clipboard.setData] — the app never fakes it.
class CopyButton extends ConsumerWidget {
  const CopyButton({
    required this.text,
    this.label,
    this.icon = Icons.copy,
    this.filled = false,
    super.key,
  });

  final String text;
  final String? label;
  final IconData icon;
  final bool filled;

  Future<void> _copy(BuildContext context, AppStrings strings) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(strings.copiedToClipboard)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final effectiveLabel = label ?? strings.copy;

    if (filled) {
      return FilledButton.icon(
        onPressed: () => _copy(context, strings),
        icon: Icon(icon),
        label: Text(effectiveLabel),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => _copy(context, strings),
      icon: Icon(icon),
      label: Text(effectiveLabel),
    );
  }
}
