import 'package:drift/drift.dart';

import '../../shared/enums/enums.dart';

/// Drift table definitions for Clipboard's local SQLite database.
///
/// Row data classes are renamed with `@DataClassName` so they do not collide
/// with the pure domain entities (e.g. the `Folder` domain class vs the
/// `FolderRow` generated row class).
///
/// Enums are stored as their integer index via `intEnum`. Never reorder the
/// enum values without a matching migration, as the index is what is persisted.

@DataClassName('FolderRow')
@TableIndex(name: 'idx_folders_parent', columns: {#parentId})
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get parentId => text().nullable().references(Folders, #id)();
  TextColumn get path => text().nullable()();
  BoolColumn get isRoot => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  // Sync-ready fields (unused for the local MVP, reserved for future sync).
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AssetRow')
@TableIndex(name: 'idx_assets_folder', columns: {#folderId})
@TableIndex(name: 'idx_assets_type', columns: {#type})
@TableIndex(name: 'idx_assets_hash', columns: {#fileHash})
class Assets extends Table {
  TextColumn get id => text()();
  TextColumn get folderId => text().references(Folders, #id)();
  TextColumn get name => text()();
  IntColumn get type => intEnum<AssetType>()();
  TextColumn get localPath => text().nullable()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get textContent => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get status =>
      intEnum<AssetStatus>().withDefault(Constant(AssetStatus.draft.index))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get fileHash => text().nullable()();

  // Sync-ready fields.
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AssetTagRow')
class AssetTags extends Table {
  TextColumn get assetId => text().references(Assets, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column<Object>> get primaryKey => {assetId, tagId};
}

@DataClassName('PlatformRow')
class Platforms extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AssetPlatformRow')
class AssetPlatforms extends Table {
  TextColumn get assetId => text().references(Assets, #id)();
  TextColumn get platformId => text().references(Platforms, #id)();

  @override
  Set<Column<Object>> get primaryKey => {assetId, platformId};
}

@DataClassName('PostRow')
@TableIndex(name: 'idx_posts_folder', columns: {#folderId})
class Posts extends Table {
  TextColumn get id => text()();
  TextColumn get folderId => text().references(Folders, #id)();
  TextColumn get title => text()();
  TextColumn get caption => text().withDefault(const Constant(''))();

  /// Hashtags and platforms are stored as JSON-encoded string lists.
  TextColumn get hashtags => text().withDefault(const Constant('[]'))();
  TextColumn get platforms => text().withDefault(const Constant('[]'))();

  IntColumn get status =>
      intEnum<PostStatus>().withDefault(Constant(PostStatus.draft.index))();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  // Sync-ready fields.
  TextColumn get remoteId => text().nullable()();
  TextColumn get syncStatus => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PostMediaRow')
class PostMedia extends Table {
  TextColumn get postId => text().references(Posts, #id)();
  TextColumn get assetId => text().references(Assets, #id)();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {postId, assetId};
}

@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
