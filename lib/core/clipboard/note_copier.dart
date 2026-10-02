// Copies a note's text and its attached media to the system clipboard as a
// single clipboard entry, so one paste yields the text (in text targets) and
// media files where supported. Uses super_clipboard on desktop/mobile;
// the web stub falls back to text-only (no local files in a browser sandbox).
import 'note_copier_stub.dart' if (dart.library.io) 'note_copier_io.dart'
    as impl;

/// Copies [text] plus, when possible, the [imagePaths] attachments. Returns the
/// number of files actually added to the clipboard (0 = text only). Throws on
/// clipboard failure so the caller can show an error.
Future<int> copyNoteToClipboard(
  String text, {
  List<String> imagePaths = const [],
}) =>
    impl.copyNoteToClipboard(text, imagePaths);
