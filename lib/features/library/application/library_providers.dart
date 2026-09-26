import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/workspace_providers.dart';
import '../data/library_repository.dart';
import '../data/metadata_store.dart';
import '../data/trash_store.dart';
import '../domain/library_entry.dart';

/// The filesystem repository bound to the current workspace, or null if no
/// workspace has been chosen yet.
final libraryRepositoryProvider = Provider<LibraryRepository?>((ref) {
  final root = ref.watch(workspaceRootProvider);
  if (root == null) return null;
  return LibraryRepository(
    root: root,
    metadata: MetadataStore(root),
    trash: TrashStore(root),
  );
});

/// Live listing of a directory. Re-scans on any filesystem change in that
/// directory, so files dropped in (from the app or from the OS) appear
/// automatically.
final directoryProvider = StreamProvider.autoDispose
    .family<List<LibraryEntry>, String>((ref, dirPath) async* {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) {
    yield const [];
    return;
  }
  yield await repo.listEntries(dirPath);
  try {
    await for (final _ in Directory(dirPath).watch()) {
      yield await repo.listEntries(dirPath);
    }
  } catch (_) {
    // Directory watching is best-effort; ignore watcher errors.
  }
});

/// Trashed entries for the current workspace.
final trashProvider = FutureProvider.autoDispose<List<TrashEntry>>((ref) async {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) return const [];
  return repo.listTrash();
});

/// Controller for library mutations. Callers pass the directory that should be
/// refreshed so metadata-only changes (which don't trigger the fs watcher)
/// still update the UI.
final libraryControllerProvider = Provider<LibraryController>((ref) {
  return LibraryController(ref);
});

class LibraryController {
  LibraryController(this._ref);

  final Ref _ref;

  LibraryRepository get _repo {
    final repo = _ref.read(libraryRepositoryProvider);
    if (repo == null) {
      throw StateError('Aucun dossier de travail sélectionné.');
    }
    return repo;
  }

  Future<String> createFolder(String parentPath, String name) async {
    final path = await _repo.createFolder(parentPath, name);
    _ref.invalidate(directoryProvider(parentPath));
    return path;
  }

  Future<String> createNote(
    String dirPath, {
    required String title,
    required String content,
  }) async {
    final path = await _repo.createNote(dirPath, title: title, content: content);
    _ref.invalidate(directoryProvider(dirPath));
    return path;
  }

  Future<String> readNote(String path) => _repo.readTextFile(path);

  Future<void> saveNote(String path, String content) =>
      _repo.writeTextFile(path, content);

  Future<String> rename(String path, String newName, {String? parentDir}) async {
    final result = await _repo.rename(path, newName);
    if (parentDir != null) _ref.invalidate(directoryProvider(parentDir));
    return result;
  }

  Future<void> setFavorite(String path, bool value, {String? parentDir}) async {
    await _repo.setFavorite(path, value);
    if (parentDir != null) _ref.invalidate(directoryProvider(parentDir));
  }

  Future<List<String>> importPaths(
      String destDir, List<String> sourcePaths) async {
    final failed = await _repo.importPaths(destDir, sourcePaths);
    _ref.invalidate(directoryProvider(destDir));
    return failed;
  }

  Future<void> moveToTrash(String path, {String? parentDir}) async {
    await _repo.moveToTrash(path);
    if (parentDir != null) _ref.invalidate(directoryProvider(parentDir));
    _ref.invalidate(trashProvider);
  }

  Future<void> restoreFromTrash(String id) async {
    await _repo.restoreFromTrash(id);
    _ref.invalidate(trashProvider);
  }

  Future<void> deleteForever(String id) async {
    await _repo.deleteForever(id);
    _ref.invalidate(trashProvider);
  }

  Future<void> emptyTrash() async {
    await _repo.emptyTrash();
    _ref.invalidate(trashProvider);
  }
}
