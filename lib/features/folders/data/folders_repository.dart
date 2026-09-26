import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/folder.dart';

/// Data-access layer for folders, backed by Drift/SQLite.
///
/// All read methods that power the UI expose reactive [Stream]s so that the
/// interface refreshes automatically when the underlying data changes.
class FoldersRepository {
  FoldersRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  // --- Reads -----------------------------------------------------------------

  /// Watches the (non-deleted) direct children of [parentId], ordered by name.
  Stream<List<Folder>> watchChildFolders(String parentId) {
    final query = _db.select(_db.folders)
      ..where((t) => t.parentId.equals(parentId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<Folder?> getFolder(String id) async {
    final row = await (_db.select(_db.folders)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Returns the auto-created root ("Main") folder, or `null` before seeding.
  Future<Folder?> getRootFolder() async {
    final row = await (_db.select(_db.folders)
          ..where((t) => t.isRoot.equals(true)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Watches all soft-deleted folders (for the trash screen).
  Stream<List<Folder>> watchTrashedFolders() {
    final query = _db.select(_db.folders)
      ..where((t) => t.deletedAt.isNotNull())
      ..orderBy([(t) => OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  // --- Writes ----------------------------------------------------------------

  Future<Folder> createFolder({required String name, String? parentId}) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await _db.into(_db.folders).insert(
          FoldersCompanion.insert(
            id: id,
            name: name,
            parentId: Value(parentId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await getFolder(id))!;
  }

  Future<void> renameFolder(String id, String name) async {
    await (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(
      FoldersCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> moveFolder(String id, String? newParentId) async {
    await (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(
      FoldersCompanion(
        parentId: Value(newParentId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Soft-deletes a folder (recoverable from the trash).
  Future<void> deleteFolder(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(
      FoldersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> restoreFolder(String id) async {
    await (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(
      FoldersCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> permanentlyDeleteFolder(String id) async {
    await (_db.delete(_db.folders)..where((t) => t.id.equals(id))).go();
  }

  // --- Mapping ---------------------------------------------------------------

  Folder _toDomain(FolderRow r) => Folder(
        id: r.id,
        name: r.name,
        parentId: r.parentId,
        path: r.path,
        isRoot: r.isRoot,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        deletedAt: r.deletedAt,
      );
}
