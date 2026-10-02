import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../clipboard/note_copier.dart';
import '../formatting/note_clipboard.dart';
import '../l10n/app_strings.dart';

enum _NoteCopyAction { noteOnly, noteWithMedia }

typedef NoteCopyHandler = Future<void> Function(
  BuildContext context,
  AppStrings strings,
  String text, {
  List<String> mediaPaths,
});

/// A copy action offering the note's practical copy strategies:
///   • Copy the note text only.
///   • Copy the note with selected/attached media.
class CopyMenuButton extends ConsumerWidget {
  const CopyMenuButton({
    required this.content,
    this.imagePaths = const [],
    this.asMenuItems = false,
    this.onCopy,
    super.key,
  });

  /// The note's text (already native styled Unicode).
  final String content;

  /// Absolute paths of the note's active media attachments.
  final List<String> imagePaths;
  final bool asMenuItems;
  final NoteCopyHandler? onCopy;

  static const _clip = NoteClipboard();

  Future<void> copy(
    BuildContext context,
    AppStrings strings,
    String text, {
    List<String> mediaPaths = const [],
  }) async {
    try {
      final files = await copyNoteToClipboard(text, imagePaths: mediaPaths);
      if (!context.mounted) return;
      final message = files > 0
          ? strings.copiedWithFiles(files)
          : strings.copiedToClipboard;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(strings.copyFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    if (asMenuItems) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<_NoteCopyAction>(
      icon: const Icon(Icons.copy),
      tooltip: strings.copy,
      onSelected: (action) async {
        final text = _clip.render(CopyMode.social, content);
        switch (action) {
          case _NoteCopyAction.noteOnly:
            await (onCopy ?? copy)(context, strings, text);
          case _NoteCopyAction.noteWithMedia:
            await (onCopy ?? copy)(
              context,
              strings,
              text,
              mediaPaths: imagePaths,
            );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _NoteCopyAction.noteOnly,
          child: _row(Icons.notes_outlined, strings.copyForSocial),
        ),
        PopupMenuItem(
          value: _NoteCopyAction.noteWithMedia,
          child: _row(Icons.perm_media_outlined, strings.copyPlainText),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      );
}
