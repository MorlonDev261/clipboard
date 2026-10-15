import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';

/// `false` = normal mode (read, tick checklist items), `true` = edit mode
/// (add, change, delete). Shared by Tasks and Accounting; starts in normal
/// mode on every launch so nothing is changed by accident.
class EditModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final editModeProvider =
    NotifierProvider<EditModeNotifier, bool>(EditModeNotifier.new);

/// App-bar button switching between normal and edit mode.
class EditModeButton extends ConsumerWidget {
  const EditModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final editing = ref.watch(editModeProvider);
    return IconButton(
      key: const ValueKey('edit-mode-toggle'),
      tooltip: editing ? strings.normalMode : strings.editMode,
      icon: Icon(editing ? Icons.check : Icons.edit_outlined),
      onPressed: ref.read(editModeProvider.notifier).toggle,
    );
  }
}
