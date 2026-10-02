import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/services/atomic_file.dart';

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
        deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Index of trashed entries stored at `<root>/.clipboard/trash.json`.
///
/// The index lives inside the workspace, so it is **untrusted input** (a
/// workspace received as a zip can carry a crafted one). Absolute paths in it
/// are never followed: [resolve] rebuilds the trashed location from the id and
/// name, and only accepts a restore target that is inside the workspace.
class TrashStore {
  TrashStore(this.root);

  final String root;
  final _lock = AsyncMutex();

  Directory get trashDir => Directory(p.join(root, '.clipboard', 'trash'));
  File get _index => File(p.join(root, '.clipboard', 'trash.json'));

  Future<List<TrashEntry>> list() async {
    try {
      if (!await _index.exists()) return [];
      final data = jsonDecode(await _index.readAsString(encoding: utf8));
      if (data is! List) throw const FormatException('trash index');
      final entries = data
          .whereType<Map<String, dynamic>>()
          .map(TrashEntry.fromJson)
          .toList();
      entries.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      return entries;
    } catch (_) {
      await _backupCorruptIndex();
      return [];
    }
  }

  /// A damaged index must never be silently overwritten by the next `add`:
  /// keep a copy so the entries can be recovered by hand.
  Future<void> _backupCorruptIndex() async {
    try {
      final backup = File('${_index.path}.corrupt');
      if (await _index.exists() && !await backup.exists()) {
        await _index.copy(backup.path);
      }
    } catch (_) {
      // best effort
    }
  }

  Future<void> _save(List<TrashEntry> entries) => writeStringAtomic(
        _index,
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      );

  Future<void> add(TrashEntry entry) => _lock.run(() async {
        final entries = await list();
        entries.add(entry);
        await _save(entries);
      });

  Future<void> remove(String id) => _lock.run(() async {
        final entries = await list();
        entries.removeWhere((e) => e.id == id);
        await _save(entries);
      });

  Future<TrashEntry?> find(String id) async {
    final entries = await list();
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// The real location of a trashed entry: always inside [trashDir], derived
  /// from the id and name — never from the path stored in the index.
  String resolve(TrashEntry entry) {
    final safeName = p.basename(entry.name);
    final id = entry.id.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');
    return p.join(trashDir.path, '${id}__$safeName');
  }
}
