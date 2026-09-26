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

/// A single asset by id, reactive (used by the detail screen).
final assetProvider = StreamProvider.family<Asset?, String>((ref, id) {
  return ref.watch(assetsRepositoryProvider).watchAsset(id);
});

/// Controller that owns asset mutations, keeping this logic out of widgets.
final assetsControllerProvider = Provider<AssetsController>((ref) {
  return AssetsController(ref.watch(assetsRepositoryProvider));
});

class AssetsController {
  AssetsController(this._repository);

  final AssetsRepository _repository;

  Future<Asset> createText({
    required String folderId,
    required String text,
    String? title,
    AssetStatus status = AssetStatus.draft,
  }) {
    if (text.trim().isEmpty) {
      throw ArgumentError('Le texte ne peut pas être vide.');
    }
    return _repository.createTextAsset(
      folderId: folderId,
      text: text.trim(),
      title: title?.trim(),
      status: status,
    );
  }

  Future<void> updateText(
    String id, {
    required String text,
    String? title,
    AssetStatus? status,
  }) {
    if (text.trim().isEmpty) {
      throw ArgumentError('Le texte ne peut pas être vide.');
    }
    return _repository.updateTextAsset(
      id,
      text: text.trim(),
      title: title?.trim(),
      status: status,
    );
  }

  Future<void> toggleFavorite(Asset asset) =>
      _repository.setFavorite(asset.id, !asset.isFavorite);

  Future<void> delete(Asset asset) => _repository.deleteAsset(asset.id);
}
