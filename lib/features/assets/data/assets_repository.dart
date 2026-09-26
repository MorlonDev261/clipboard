import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/enums/enums.dart';
import '../domain/asset.dart';

/// Data-access layer for assets, backed by Drift/SQLite.
class AssetsRepository {
  AssetsRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  // --- Reads -----------------------------------------------------------------

  /// Watches the (non-deleted) assets of a folder, most recent first.
  Stream<List<Asset>> watchAssetsByFolder(String folderId) {
    final query = _db.select(_db.assets)
      ..where((t) => t.folderId.equals(folderId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<Asset?> getAsset(String id) async {
    final row = await (_db.select(_db.assets)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Watches a single asset (for the detail screen), reactive.
  Stream<Asset?> watchAsset(String id) {
    final query = _db.select(_db.assets)..where((t) => t.id.equals(id));
    return query.watchSingleOrNull().map((r) => r == null ? null : _toDomain(r));
  }

  Stream<List<Asset>> watchFavorites() {
    final query = _db.select(_db.assets)
      ..where((t) => t.isFavorite.equals(true) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<int> countByType(AssetType type) async {
    final count = _db.assets.id.count();
    final query = _db.selectOnly(_db.assets)
      ..addColumns([count])
      ..where(_db.assets.type.equalsValue(type) & _db.assets.deletedAt.isNull());
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> countFavorites() async {
    final count = _db.assets.id.count();
    final query = _db.selectOnly(_db.assets)
      ..addColumns([count])
      ..where(_db.assets.isFavorite.equals(true) & _db.assets.deletedAt.isNull());
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // --- Writes ----------------------------------------------------------------

  /// Creates a reusable text asset. [name] is derived from the title or the
  /// first line of the text when no title is given.
  Future<Asset> createTextAsset({
    required String folderId,
    required String text,
    String? title,
    AssetStatus status = AssetStatus.draft,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final displayName = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : _deriveName(text);
    await _db.into(_db.assets).insert(
          AssetsCompanion.insert(
            id: id,
            folderId: folderId,
            name: displayName,
            type: AssetType.text,
            textContent: Value(text),
            title: Value(title),
            status: Value(status),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await getAsset(id))!;
  }

  Future<void> updateTextAsset(
    String id, {
    required String text,
    String? title,
    AssetStatus? status,
  }) async {
    final displayName = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : _deriveName(text);
    await (_db.update(_db.assets)..where((t) => t.id.equals(id))).write(
      AssetsCompanion(
        name: Value(displayName),
        textContent: Value(text),
        title: Value(title),
        status: status == null ? const Value.absent() : Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setFavorite(String id, bool value) async {
    await (_db.update(_db.assets)..where((t) => t.id.equals(id))).write(
      AssetsCompanion(
        isFavorite: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Soft-deletes an asset (recoverable from the trash).
  Future<void> deleteAsset(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.assets)..where((t) => t.id.equals(id))).write(
      AssetsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  String _deriveName(String text) {
    final firstLine = text.trim().split('\n').first.trim();
    if (firstLine.isEmpty) return 'Texte';
    return firstLine.length > 60 ? '${firstLine.substring(0, 60)}…' : firstLine;
  }

  // --- Mapping ---------------------------------------------------------------

  Asset _toDomain(AssetRow r) => Asset(
        id: r.id,
        folderId: r.folderId,
        name: r.name,
        type: r.type,
        localPath: r.localPath,
        thumbnailPath: r.thumbnailPath,
        mimeType: r.mimeType,
        fileSize: r.fileSize,
        durationMs: r.durationMs,
        textContent: r.textContent,
        title: r.title,
        description: r.description,
        isFavorite: r.isFavorite,
        status: r.status,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        deletedAt: r.deletedAt,
        fileHash: r.fileHash,
      );
}
