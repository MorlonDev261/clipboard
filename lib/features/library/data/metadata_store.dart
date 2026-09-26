import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Per-entry metadata that cannot live in the file itself (favorite, tags).
class EntryMeta {
  const EntryMeta({this.favorite = false, this.tags = const []});

  final bool favorite;
  final List<String> tags;

  Map<String, dynamic> toJson() => {'favorite': favorite, 'tags': tags};

  factory EntryMeta.fromJson(Map<String, dynamic> json) => EntryMeta(
        favorite: json['favorite'] == true,
        tags: (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
      );

  EntryMeta copyWith({bool? favorite, List<String>? tags}) =>
      EntryMeta(favorite: favorite ?? this.favorite, tags: tags ?? this.tags);

  bool get isEmpty => !favorite && tags.isEmpty;
}

/// Reads and writes `<root>/.clipboard/metadata.json`, keyed by the entry path
/// relative to the workspace root (posix separators, for portability).
class MetadataStore {
  MetadataStore(this.root);

  final String root;

  File get _file =>
      File(p.join(root, '.clipboard', 'metadata.json'));

  String relKey(String absolutePath) =>
      p.relative(absolutePath, from: root).replaceAll(r'\', '/');

  Future<Map<String, EntryMeta>> load() async {
    try {
      if (!await _file.exists()) return {};
      final data = jsonDecode(await _file.readAsString());
      if (data is! Map) return {};
      final result = <String, EntryMeta>{};
      data.forEach((key, value) {
        if (key is String && value is Map<String, dynamic>) {
          result[key] = EntryMeta.fromJson(value);
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<String, EntryMeta> map) async {
    await _file.parent.create(recursive: true);
    final json = <String, dynamic>{};
    map.forEach((key, meta) {
      if (!meta.isEmpty) json[key] = meta.toJson();
    });
    await _file.writeAsString(jsonEncode(json));
  }

  Future<EntryMeta> get(String absolutePath) async {
    final map = await load();
    return map[relKey(absolutePath)] ?? const EntryMeta();
  }

  Future<void> setFavorite(String absolutePath, bool value) async {
    final map = await load();
    final key = relKey(absolutePath);
    map[key] = (map[key] ?? const EntryMeta()).copyWith(favorite: value);
    await _save(map);
  }

  Future<void> setTags(String absolutePath, List<String> tags) async {
    final map = await load();
    final key = relKey(absolutePath);
    map[key] = (map[key] ?? const EntryMeta()).copyWith(tags: tags);
    await _save(map);
  }

  /// Moves metadata from one path to another (on rename / move). Also handles
  /// children when a folder is moved.
  Future<void> move(String fromAbsolute, String toAbsolute) async {
    final map = await load();
    final fromKey = relKey(fromAbsolute);
    final toKey = relKey(toAbsolute);
    var changed = false;
    // Re-key the entry and any descendants (folder move).
    for (final key in map.keys.toList()) {
      if (key == fromKey || key.startsWith('$fromKey/')) {
        final suffix = key.substring(fromKey.length);
        map['$toKey$suffix'] = map.remove(key)!;
        changed = true;
      }
    }
    if (changed) await _save(map);
  }

  /// Removes metadata for an entry (and descendants).
  Future<void> remove(String absolutePath) async {
    final map = await load();
    final key = relKey(absolutePath);
    final before = map.length;
    map.removeWhere((k, _) => k == key || k.startsWith('$key/'));
    if (map.length != before) await _save(map);
  }
}
