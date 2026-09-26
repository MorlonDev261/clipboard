import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../data/folders_repository.dart';
import '../domain/folder.dart';

/// Repository access.
final foldersRepositoryProvider = Provider<FoldersRepository>((ref) {
  return FoldersRepository(ref.watch(databaseProvider));
});

/// The auto-created "Main" root folder.
final rootFolderProvider = FutureProvider<Folder>((ref) async {
  final root = await ref.watch(foldersRepositoryProvider).getRootFolder();
  if (root == null) {
    throw StateError('Le dossier racine « Main » est introuvable.');
  }
  return root;
});

/// A single folder by id (used for the folder screen header / breadcrumbs).
final folderProvider = FutureProvider.family<Folder?, String>((ref, id) {
  return ref.watch(foldersRepositoryProvider).getFolder(id);
});

/// The direct sub-folders of a given folder, reactive.
final childFoldersProvider =
    StreamProvider.family<List<Folder>, String>((ref, parentId) {
  return ref.watch(foldersRepositoryProvider).watchChildFolders(parentId);
});

/// Soft-deleted folders, for the trash screen.
final trashedFoldersProvider = StreamProvider<List<Folder>>((ref) {
  return ref.watch(foldersRepositoryProvider).watchTrashedFolders();
});

/// Controller that owns folder mutations, keeping this logic out of widgets.
final foldersControllerProvider = Provider<FoldersController>((ref) {
  return FoldersController(ref.watch(foldersRepositoryProvider));
});

/// Thin application-layer controller wrapping folder write operations.
class FoldersController {
  FoldersController(this._repository);

  final FoldersRepository _repository;

  Future<Folder> createFolder({required String name, String? parentId}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Le nom du dossier ne peut pas être vide.');
    }
    return _repository.createFolder(name: trimmed, parentId: parentId);
  }

  Future<void> renameFolder(Folder folder, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Le nom du dossier ne peut pas être vide.');
    }
    return _repository.renameFolder(folder.id, trimmed);
  }

  /// Soft-deletes a folder. The root "Main" folder can never be deleted.
  Future<void> deleteFolder(Folder folder) {
    if (folder.isRoot) {
      throw StateError('Le dossier Main ne peut pas être supprimé.');
    }
    return _repository.deleteFolder(folder.id);
  }

  Future<void> restoreFolder(Folder folder) =>
      _repository.restoreFolder(folder.id);

  Future<void> permanentlyDeleteFolder(Folder folder) =>
      _repository.permanentlyDeleteFolder(folder.id);
}
