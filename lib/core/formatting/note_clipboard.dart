import 'unicode_styler.dart';

/// The copy strategies offered for a note.
enum CopyMode {
  /// The note as written — already native styled Unicode, ready to paste into
  /// social networks / plain-text fields.
  social,

  /// The note with all styling removed (plain ASCII + accents).
  plainText,
}

/// Pure text rendering for each [CopyMode]. No UI, no platform calls — the
/// `Clipboard.setData` and user feedback live in the widget layer.
class NoteClipboard {
  const NoteClipboard({this.styler = const UnicodeStyler()});

  final UnicodeStyler styler;

  /// Renders the note [content] for [mode].
  String render(CopyMode mode, String content) {
    switch (mode) {
      case CopyMode.social:
        return content; // already native styled Unicode
      case CopyMode.plainText:
        return styler.plainify(content);
    }
  }
}
