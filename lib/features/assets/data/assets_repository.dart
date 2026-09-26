import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/enums/enums.dart';
import '../domain/asset.dart';

/// Data-access layer for assets, backed by Drift/SQLite.
class AssetsRepository {
  AssetsRepository(this._db);

  final AppDatabase _db;

  // --- Reads -----------------------------------------------------------------

  /// Watches the (non-deleted) assets of a folder, most recent first.
  Stream<List<Asset>> watchAssetsByFolder(String folderId) {
    final query = _db.select(_db.assets)
      ..where((t) => t.folderId.equals(folderId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
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
