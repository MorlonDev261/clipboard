import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../shared/enums/enums.dart';

/// Aggregated counters shown on the home dashboard.
typedef DashboardStats = ({
  int images,
  int videos,
  int texts,
  int posts,
  int favorites,
});

/// Computes dashboard counts in a single provider using efficient
/// `COUNT(*)` queries (no full-table loads).
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final db = ref.watch(databaseProvider);

  Future<int> countAssets(AssetType type) async {
    final count = db.assets.id.count();
    final query = db.selectOnly(db.assets)
      ..addColumns([count])
      ..where(db.assets.type.equalsValue(type) & db.assets.deletedAt.isNull());
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<int> countFavorites() async {
    final count = db.assets.id.count();
    final query = db.selectOnly(db.assets)
      ..addColumns([count])
      ..where(db.assets.isFavorite.equals(true) & db.assets.deletedAt.isNull());
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<int> countPosts() async {
    final count = db.posts.id.count();
    final query = db.selectOnly(db.posts)
      ..addColumns([count])
      ..where(db.posts.deletedAt.isNull());
    return (await query.getSingle()).read(count) ?? 0;
  }

  final results = await Future.wait([
    countAssets(AssetType.image),
    countAssets(AssetType.video),
    countAssets(AssetType.text),
    countPosts(),
    countFavorites(),
  ]);

  return (
    images: results[0],
    videos: results[1],
    texts: results[2],
    posts: results[3],
    favorites: results[4],
  );
});
