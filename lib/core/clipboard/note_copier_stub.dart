import 'package:flutter/services.dart';

/// Web fallback: a browser sandbox has no local files, so only the text is
/// copied.
Future<int> copyNoteToClipboard(String text, List<String> imagePaths) async {
  await Clipboard.setData(ClipboardData(text: text));
  return 0;
}
