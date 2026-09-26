import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/workspace_providers.dart';
import '../../../shared/enums/enums.dart';
import '../data/library_repository.dart';
import '../data/metadata_store.dart';
import '../data/trash_store.dart';
import '../domain/library_entry.dart';

/// Active sort order in the browser (session state).
final browseSortProvider = StateProvider<SortOption>((ref) => SortOption.nameAsc);

/// Active kind filter in the browser; null means "all" (session state).
final browseFilterProvider = StateProvider<EntryKind?>((ref) => null);

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

/// Flat, recursive index of every entry in the workspace (for search &
/// favorites). Kept alive so it isn't rebuilt on every keystroke.
final libraryIndexProvider = FutureProvider<List<LibraryEntry>>((ref) async {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) return const [];
  return repo.listAllEntries();
});

/// All favorite entries across the workspace.
final favoritesProvider = FutureProvider<List<LibraryEntry>>((ref) async {
  final all = await ref.watch(libraryIndexProvider.future);
  return all.where((e) => e.isFavorite).toList();
});

/// Recursive counts for a folder (the folder itself + all sub-folders).
typedef DirStats = ({int folders, int images, int videos, int notes});

final dirStatsProvider =
    FutureProvider.family<DirStats, String>((ref, dirPath) async {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) return (folders: 0, images: 0, videos: 0, notes: 0);
  final all = await repo.listAllUnder(dirPath);
  return (
    folders: all.where((e) => e.isFolder).length,
    images: all.where((e) => e.isImage).length,
    videos: all.where((e) => e.isVideo).length,
    notes: all.where((e) => e.isNote).length,
  );
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

  void _touchIndex() {
    _ref.invalidate(libraryIndexProvider);
    _ref.invalidate(dirStatsProvider); // refresh all folder stat cards
  }

  Future<String> createFolder(String parentPath, String name) async {
    final path = await _repo.createFolder(parentPath, name);
    _ref.invalidate(directoryProvider(parentPath));
    _touchIndex();
    return path;
  }

  Future<String> createNote(
    String dirPath, {
    required String title,
    required String content,
  }) async {
    final path = await _repo.createNote(dirPath, title: title, content: content);
    _ref.invalidate(directoryProvider(dirPath));
    _touchIndex();
    return path;
  }

  Future<String> readNote(String path) => _repo.readTextFile(path);

  Future<void> saveNote(String path, String content) =>
      _repo.writeTextFile(path, content);

  Future<String> rename(String path, String newName, {String? parentDir}) async {
    final result = await _repo.rename(path, newName);
    if (parentDir != null) _ref.invalidate(directoryProvider(parentDir));
    _touchIndex();
    return result;
  }

  Future<void> setFavorite(String path, bool value, {String? parentDir}) async {
    await _repo.setFavorite(path, value);
    if (parentDir != null) _ref.invalidate(directoryProvider(parentDir));
    _touchIndex();
  }

  Future<void> setTags(String path, List<String> tags, {String? parentDir}) async {
    await _repo.setTags(path, tags);
    if (parentDir != null) _ref.invalidate(directoryProvider(parentDir));
    _touchIndex();
  }

  Future<List<String>> importPaths(
      String destDir, List<String> sourcePaths) async {
    final failed = await _repo.importPaths(destDir, sourcePaths);
    _ref.invalidate(directoryProvider(destDir));
    _touchIndex();
    return failed;
  }

  Future<void> move(String path, String destDir, {String? parentDir}) async {
    await _repo.move(path, destDir);
    if (parentDir != null) _ref.invalidate(directoryProvider(parentDir));
    _ref.invalidate(directoryProvider(destDir));
    _touchIndex();
  }

  Future<void> duplicate(String path, {String? parentDir}) async {
    await _repo.duplicate(path);
    if (parentDir != null) _ref.invalidate(directoryProvider(parentDir));
    _touchIndex();
  }

  Future<void> moveToTrash(String path, {String? parentDir}) async {
    await _repo.moveToTrash(path);
    if (parentDir != null) _ref.invalidate(directoryProvider(parentDir));
    _ref.invalidate(trashProvider);
    _touchIndex();
  }

  Future<void> restoreFromTrash(String id) async {
    await _repo.restoreFromTrash(id);
    _ref.invalidate(trashProvider);
    _touchIndex();
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
