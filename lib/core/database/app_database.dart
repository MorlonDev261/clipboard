import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

// The generated part (app_database.g.dart) references these enum types, so the
// enclosing library must import them here (imports are not transitive).
import '../../shared/enums/enums.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The Clipboard local database.
///
/// Run code generation after modifying tables:
/// `dart run build_runner build --delete-conflicting-outputs`
@DriftDatabase(
  tables: [
    Folders,
    Assets,
    Tags,
    AssetTags,
    Platforms,
    AssetPlatforms,
    Posts,
    PostMedia,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        beforeOpen: (OpeningDetails details) async {
          // Enable foreign key enforcement on every connection.
          await customStatement('PRAGMA foreign_keys = ON');
          if (details.wasCreated) {
            await _seedInitialData();
          }
        },
      );

  /// Seeds the database on first launch: the "Main" root folder, the default
  /// social platforms and the stored schema version.
  Future<void> _seedInitialData() async {
    const uuid = Uuid();
    final now = DateTime.now();

    await into(folders).insert(
      FoldersCompanion.insert(
        id: uuid.v4(),
        name: 'Main',
        isRoot: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
    );

    const defaultPlatforms = [
      'Facebook',
      'Instagram',
      'TikTok',
      'WhatsApp',
      'LinkedIn',
      'X',
    ];
    for (final name in defaultPlatforms) {
      await into(platforms).insert(
        PlatformsCompanion.insert(id: uuid.v4(), name: name),
      );
    }

    await into(appSettings).insert(
      AppSettingsCompanion.insert(
        key: 'db_version',
        value: const Value('1'),
      ),
    );
  }
}

/// Opens a platform-appropriate connection (mobile, desktop and web) via
/// `drift_flutter`, which resolves the correct storage location internally.
QueryExecutor _openConnection() {
  return driftDatabase(name: 'clipboard');
}
