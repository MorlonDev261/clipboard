import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../clipboard/note_copier.dart';
import '../formatting/note_clipboard.dart';
import '../l10n/app_strings.dart';

/// A copy action offering the note's copy strategies:
///   • Copy for social media — the note as written (native styled Unicode)
///   • Copy as plain text — styling removed
///
/// The text is rendered by the pure [NoteClipboard]; the attached images (if
/// any) are copied alongside the text as a single clipboard entry, so one paste
/// yields the text in text fields and the image(s) in image fields.
class CopyMenuButton extends ConsumerWidget {
  const CopyMenuButton({
    required this.content,
    this.imagePaths = const [],
    super.key,
  });

  /// The note's text (already native styled Unicode).
  final String content;

  /// Absolute paths of the note's attached images, copied with the text.
  final List<String> imagePaths;

  static const _clip = NoteClipboard();

  Future<void> _copy(
      BuildContext context, AppStrings strings, String text) async {
    try {
      final files = await copyNoteToClipboard(text, imagePaths: imagePaths);
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
    return PopupMenuButton<CopyMode>(
      icon: const Icon(Icons.copy),
      tooltip: strings.copy,
      onSelected: (mode) =>
          _copy(context, strings, _clip.render(mode, content)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: CopyMode.social,
          child: _row(Icons.emoji_emotions_outlined, strings.copyForSocial),
        ),
        PopupMenuItem(
          value: CopyMode.plainText,
          child: _row(Icons.notes_outlined, strings.copyPlainText),
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
