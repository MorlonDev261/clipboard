import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../shared/enums/enums.dart';
import '../data/assets_repository.dart';
import '../domain/asset.dart';

final assetsRepositoryProvider = Provider<AssetsRepository>((ref) {
  return AssetsRepository(ref.watch(databaseProvider));
});

/// Reactive assets of a folder.
final folderAssetsProvider =
    StreamProvider.family<List<Asset>, String>((ref, folderId) {
  return ref.watch(assetsRepositoryProvider).watchAssetsByFolder(folderId);
});

/// Reactive favorites list.
final favoriteAssetsProvider = StreamProvider<List<Asset>>((ref) {
  return ref.watch(assetsRepositoryProvider).watchFavorites();
});

/// Count of assets of a given type (used by the home dashboard).
final assetTypeCountProvider =
    FutureProvider.family<int, AssetType>((ref, type) {
  return ref.watch(assetsRepositoryProvider).countByType(type);
});
