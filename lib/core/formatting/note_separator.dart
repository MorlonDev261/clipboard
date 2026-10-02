/// Shared note-block separator handling for preview, copy, share and read mode.
class NoteSeparator {
  const NoteSeparator._();

  static const defaultSeparator = '\n\n';

  static String? normalize(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.replaceAll(r'\n', '\n');
  }

  static String effective(String? noteSeparator, String? globalSeparator) =>
      normalize(noteSeparator) ??
      normalize(globalSeparator) ??
      defaultSeparator;

  static List<String> segments(String text, String separator) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final customSeparator = normalize(separator);
    if (customSeparator == null || _isDefaultSeparator(customSeparator)) {
      return _paragraphSegments(normalized);
    }

    return normalized
        .split(customSeparator)
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
  }

  static String render(String text, String separator) =>
      segments(text, separator).join(separator);

  static bool _isDefaultSeparator(String separator) =>
      separator == defaultSeparator || separator == '\n';

  static List<String> _paragraphSegments(String text) => text
      .split(RegExp(r'\n[ \t]*\n+'))
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();
}
