import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/services/atomic_file.dart';

import '../../../core/formatting/note_separator.dart';

/// Per-entry metadata that cannot live in the file itself (favorite, tags).
class EntryMeta {
  const EntryMeta({
    this.favorite = false,
    this.tags = const [],
    this.noteSeparator,
  });

  final bool favorite;
  final List<String> tags;
  final String? noteSeparator;

  Map<String, dynamic> toJson() => {
        'favorite': favorite,
        'tags': tags,
        if (noteSeparator != null) 'noteSeparator': noteSeparator,
      };

  factory EntryMeta.fromJson(Map<String, dynamic> json) {
    final rawSeparator = json['noteSeparator'];
    return EntryMeta(
      favorite: json['favorite'] == true,
      tags: (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
      noteSeparator:
          rawSeparator is String ? NoteSeparator.normalize(rawSeparator) : null,
    );
  }

  EntryMeta copyWith({
    bool? favorite,
    List<String>? tags,
    String? noteSeparator,
    bool clearNoteSeparator = false,
  }) =>
      EntryMeta(
        favorite: favorite ?? this.favorite,
        tags: tags ?? this.tags,
        noteSeparator:
            clearNoteSeparator ? null : noteSeparator ?? this.noteSeparator,
      );

  bool get isEmpty => !favorite && tags.isEmpty && noteSeparator == null;
}

/// Reads and writes `<root>/.clipboard/metadata.json`, keyed by the entry path
/// relative to the workspace root (posix separators, for portability).
class MetadataStore {
  MetadataStore(this.root);

  final String root;
  final _lock = AsyncMutex();

  File get _file => File(p.join(root, '.clipboard', 'metadata.json'));

  String relKey(String absolutePath) =>
      p.relative(absolutePath, from: root).replaceAll(r'\', '/');

  Future<Map<String, EntryMeta>> load() async {
    try {
      if (!await _file.exists()) return {};
      final data = jsonDecode(await _file.readAsString(encoding: utf8));
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
    final json = <String, dynamic>{};
    map.forEach((key, meta) {
      if (!meta.isEmpty) json[key] = meta.toJson();
    });
    await writeStringAtomic(_file, jsonEncode(json));
  }

  Future<EntryMeta> get(String absolutePath) async {
    final map = await load();
    return map[relKey(absolutePath)] ?? const EntryMeta();
  }

  /// Every mutation is read → modify → write: they run one at a time so two
  /// quick changes can never overwrite each other.
  Future<void> _mutate(void Function(Map<String, EntryMeta> map) change) =>
      _lock.run(() async {
        final map = await load();
        final before = jsonEncode({
          for (final e in map.entries) e.key: e.value.toJson(),
        });
        change(map);
        final after = jsonEncode({
          for (final e in map.entries) e.key: e.value.toJson(),
        });
        if (before != after) await _save(map);
      });

  Future<void> setFavorite(String absolutePath, bool value) => _mutate((map) {
        final key = relKey(absolutePath);
        map[key] = (map[key] ?? const EntryMeta()).copyWith(favorite: value);
      });

  Future<void> setTags(String absolutePath, List<String> tags) =>
      _mutate((map) {
        final key = relKey(absolutePath);
        map[key] = (map[key] ?? const EntryMeta()).copyWith(tags: tags);
      });

  Future<void> setNoteSeparator(String absolutePath, String? separator) =>
      _mutate((map) {
        final key = relKey(absolutePath);
        final value = NoteSeparator.normalize(separator);
        map[key] = value == null || value.isEmpty
            ? (map[key] ?? const EntryMeta()).copyWith(clearNoteSeparator: true)
            : (map[key] ?? const EntryMeta()).copyWith(noteSeparator: value);
      });

  /// Moves metadata from one path to another (on rename / move). Also handles
  /// children when a folder is moved.
  Future<void> move(String fromAbsolute, String toAbsolute) => _mutate((map) {
        final fromKey = relKey(fromAbsolute);
        final toKey = relKey(toAbsolute);
        // Re-key the entry and any descendants (folder move).
        for (final key in map.keys.toList()) {
          if (key == fromKey || key.startsWith('$fromKey/')) {
            final suffix = key.substring(fromKey.length);
            map['$toKey$suffix'] = map.remove(key)!;
          }
        }
      });

  /// Removes metadata for an entry (and descendants).
  Future<void> remove(String absolutePath) => _mutate((map) {
        final key = relKey(absolutePath);
        map.removeWhere((k, _) => k == key || k.startsWith('$key/'));
      });
}
