import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// A soft-deleted entry, physically moved into `<root>/.clipboard/trash/`.
class TrashEntry {
  const TrashEntry({
    required this.id,
    required this.name,
    required this.originalPath,
    required this.trashedPath,
    required this.isDir,
    required this.deletedAt,
  });

  final String id;
  final String name;
  final String originalPath;
  final String trashedPath;
  final bool isDir;
  final DateTime deletedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'originalPath': originalPath,
        'trashedPath': trashedPath,
        'isDir': isDir,
        'deletedAt': deletedAt.toIso8601String(),
      };

  factory TrashEntry.fromJson(Map<String, dynamic> json) => TrashEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        originalPath: json['originalPath'] as String,
        trashedPath: json['trashedPath'] as String,
        isDir: json['isDir'] == true,
        deletedAt:
            DateTime.tryParse(json['deletedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Index of trashed entries stored at `<root>/.clipboard/trash.json`.
class TrashStore {
  TrashStore(this.root);

  final String root;

  Directory get trashDir => Directory(p.join(root, '.clipboard', 'trash'));
  File get _index => File(p.join(root, '.clipboard', 'trash.json'));

  Future<List<TrashEntry>> list() async {
    try {
      if (!await _index.exists()) return [];
      final data = jsonDecode(await _index.readAsString());
      if (data is! List) return [];
      final entries = data
          .whereType<Map<String, dynamic>>()
          .map(TrashEntry.fromJson)
          .toList();
      entries.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      return entries;
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<TrashEntry> entries) async {
    await _index.parent.create(recursive: true);
    await _index.writeAsString(
        jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<void> add(TrashEntry entry) async {
    final entries = await list();
    entries.add(entry);
    await _save(entries);
  }

  Future<void> remove(String id) async {
    final entries = await list();
    entries.removeWhere((e) => e.id == id);
    await _save(entries);
  }

  Future<TrashEntry?> find(String id) async {
    final entries = await list();
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }
}
