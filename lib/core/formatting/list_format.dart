/// Shared formatting for note list items, so the toolbar and the editor's
/// list-continuation logic stay in sync.
///
/// List items are indented by a small [indent] (a "petit espace avant") and use
/// a native bullet (•) or a number — no markup.
class ListFormat {
  const ListFormat._();

  /// Small leading indent shown before every list marker.
  static const String indent = '  ';
  static const String _bulletChar = '•';

  /// Prefix for a bullet item, e.g. `"  • "`.
  static const String bullet = '$indent$_bulletChar ';

  /// Prefix for the n-th numbered item, e.g. `"  1. "`.
  static String numbered(int n) => '$indent$n. ';

  /// Matches a bullet line, capturing (indent, content).
  static final RegExp bulletRe = RegExp(r'^(\s*)•[ \t]+(.*)$');

  /// Matches a numbered line, capturing (indent, number, content).
  static final RegExp numberedRe = RegExp(r'^(\s*)(\d+)[.)][ \t]+(.*)$');

  /// Matches any list prefix (bullet or number) for stripping.
  static final RegExp anyRe = RegExp(r'^(\s*)(?:•|\d+[.)])[ \t]+');
}
