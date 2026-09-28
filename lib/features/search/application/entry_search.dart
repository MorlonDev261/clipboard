import '../../library/domain/library_entry.dart';

/// Accent- and case-insensitive fold used for search matching.
String foldForSearch(String s) {
  var out = s.toLowerCase();
  const map = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  map.forEach((k, v) => out = out.replaceAll(k, v));
  return out;
}

/// Whether [e] matches the query [q] by name or tags (accent-insensitive).
bool entryMatchesQuery(LibraryEntry e, String q) {
  if (q.isEmpty) return true;
  final needle = foldForSearch(q);
  if (foldForSearch(e.displayName).contains(needle)) return true;
  return e.tags.any((t) => foldForSearch(t).contains(needle));
}
