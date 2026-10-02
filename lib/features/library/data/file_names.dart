/// Turns user input into a name every platform can create, list and delete.
///
/// * path separators and Windows-forbidden characters, plus control characters,
///   become `_`;
/// * no leading dot: the library hides dot-names (so the item would vanish) and
///   `.clipboard` / `.attachments` belong to the app;
/// * no trailing dot or space (Windows silently strips them, then cannot find
///   the file again);
/// * Windows device names (`CON`, `NUL`, `COM1`…) are prefixed — they cannot be
///   created, opened or deleted on Windows, with or without an extension;
/// * length is capped (path limits), counting UTF-16 units but never splitting
///   a surrogate pair.
String sanitizeFileName(String name, {int maxLength = 120}) {
  var s = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]'), '_').trim();
  s = s.replaceFirst(RegExp(r'^\.+'), '_');
  s = s.replaceFirst(RegExp(r'[. ]+$'), '');
  if (s.isEmpty) return 'Sans titre';

  if (_reserved.contains(s.split('.').first.trim().toUpperCase())) {
    s = '_$s';
  }

  if (s.length > maxLength) {
    var cut = maxLength;
    // Do not split a surrogate pair.
    final unit = s.codeUnitAt(cut - 1);
    if (unit >= 0xD800 && unit <= 0xDBFF) cut--;
    s = s.substring(0, cut).replaceFirst(RegExp(r'[. ]+$'), '');
    if (s.isEmpty) return 'Sans titre';
  }
  return s;
}

const _reserved = {
  'CON', 'PRN', 'AUX', 'NUL', //
  'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
  'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
};
