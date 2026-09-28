import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../domain/library_entry.dart';
import 'metadata_store.dart';
import 'trash_store.dart';

/// Filesystem-backed data layer. The workspace folder on disk is the source of
/// truth; this repository lists, creates, renames, imports and trashes real
/// files and folders, enriching them with sidecar metadata.
class LibraryRepository {
  LibraryRepository({
    required this.root,
    required MetadataStore metadata,
    required TrashStore trash,
  })  : _metadata = metadata,
        _trash = trash;

  final String root;
  final MetadataStore _metadata;
  final TrashStore _trash;
  static const _uuid = Uuid();

  // --- Listing ---------------------------------------------------------------

  /// Lists the direct children of [dirPath], hiding dotfiles (like the
  /// `.clipboard` metadata directory). Folders come first, then by name.
  Future<List<LibraryEntry>> listEntries(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];
    final meta = await _metadata.load();
    final entries = <LibraryEntry>[];

    await for (final ent in dir.list(followLinks: false)) {
      final name = p.basename(ent.path);
      if (name.startsWith('.')) continue; // skip hidden files/dirs
      FileStat stat;
      try {
        stat = await ent.stat();
      } catch (_) {
        continue;
      }
      final relKey = _metadata.relKey(ent.path);
      final m = meta[relKey];
      if (ent is Directory) {
        entries.add(LibraryEntry(
          path: ent.path,
          name: name,
          kind: EntryKind.folder,
          size: 0,
          modified: stat.modified,
          isFavorite: m?.favorite ?? false,
          tags: m?.tags ?? const [],
        ));
      } else if (ent is File) {
        entries.add(LibraryEntry(
          path: ent.path,
          name: name,
          kind: kindForFile(name),
          size: stat.size,
          modified: stat.modified,
          isFavorite: m?.favorite ?? false,
          tags: m?.tags ?? const [],
        ));
      }
    }

    entries.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return entries;
  }

  /// Recursively lists every entry under the workspace root. Used by search and
  /// favorites, which also include note attachments (media in `.attachments`).
  Future<List<LibraryEntry>> listAllEntries() =>
      listAllUnder(root, includeAttachments: true);

  /// Recursively lists every entry under [dirPath].
  ///
  /// When [includeAttachments] is true, media stored in the hidden
  /// `.attachments` folders (images/videos attached to notes) is included too —
  /// used by the folder stats so attachments are counted. The `.attachments`
  /// folder itself is never added as a folder entry.
  Future<List<LibraryEntry>> listAllUnder(
    String dirPath, {
    bool includeAttachments = false,
  }) async {
    final meta = await _metadata.load();
    final out = <LibraryEntry>[];
    await _walk(Directory(dirPath), meta, out,
        includeAttachments: includeAttachments);
    return out;
  }

  Future<void> _walk(
    Directory dir,
    Map<String, EntryMeta> meta,
    List<LibraryEntry> out, {
    bool includeAttachments = false,
  }) async {
    List<FileSystemEntity> children;
    try {
      children = await dir.list(followLinks: false).toList();
    } catch (_) {
      return;
    }
    for (final ent in children) {
      final name = p.basename(ent.path);
      if (name.startsWith('.')) {
        // Descend into note attachment folders to count embedded media, but
        // never list the hidden folder itself.
        if (includeAttachments && ent is Directory && name == '.attachments') {
          await _walk(ent, meta, out, includeAttachments: includeAttachments);
        }
        continue;
      }
      FileStat stat;
      try {
        stat = await ent.stat();
      } catch (_) {
        continue;
      }
      final m = meta[_metadata.relKey(ent.path)];
      if (ent is Directory) {
        out.add(LibraryEntry(
          path: ent.path,
          name: name,
          kind: EntryKind.folder,
          size: 0,
          modified: stat.modified,
          isFavorite: m?.favorite ?? false,
          tags: m?.tags ?? const [],
        ));
        await _walk(ent, meta, out, includeAttachments: includeAttachments);
      } else if (ent is File) {
        out.add(LibraryEntry(
          path: ent.path,
          name: name,
          kind: kindForFile(name),
          size: stat.size,
          modified: stat.modified,
          isFavorite: m?.favorite ?? false,
          tags: m?.tags ?? const [],
        ));
      }
    }
  }

  // --- Create ----------------------------------------------------------------

  Future<String> createFolder(String parentPath, String name) async {
    final dir = Directory(p.join(parentPath, _sanitize(name)));
    if (await dir.exists()) {
      throw const FileSystemException('Un dossier du même nom existe déjà.');
    }
    await dir.create();
    return dir.path;
  }

  /// Creates a `.md` note. Returns the created file path.
  Future<String> createNote(
    String dirPath, {
    required String title,
    required String content,
  }) async {
    final base = _sanitize(title.trim().isEmpty ? 'Note' : title.trim());
    var file = File(p.join(dirPath, '$base.md'));
    var i = 1;
    while (await file.exists()) {
      file = File(p.join(dirPath, '$base ($i).md'));
      i++;
    }
    await file.writeAsString(content);
    return file.path;
  }

  /// Copies an image into a hidden `.attachments` folder next to notes in
  /// [dirPath] and returns its absolute path. Hidden, so it never clutters the
  /// folder listing, but it is still counted in the folder stats (see
  /// [listAllUnder] with `includeAttachments`).
  Future<String> attachImageToDir(String dirPath, String sourcePath) async {
    final attachDir = Directory(p.join(dirPath, '.attachments'));
    await attachDir.create(recursive: true);
    final target = _uniquePath(p.join(attachDir.path, p.basename(sourcePath)));
    await File(sourcePath).copy(target);
    return target;
  }

  Future<String> readTextFile(String path) => File(path).readAsString();

  Future<void> writeTextFile(String path, String content) =>
      File(path).writeAsString(content);

  // --- Rename ----------------------------------------------------------------

  Future<String> rename(String path, String newName) async {
    final isDir = await FileSystemEntity.isDirectory(path);
    final parent = p.dirname(path);
    final String target;
    if (isDir) {
      target = p.join(parent, _sanitize(newName));
    } else {
      // Keep the original extension for files (notes stay .md).
      final ext = p.extension(path);
      final base = _sanitize(newName);
      target = p.join(parent, base.endsWith(ext) ? base : '$base$ext');
    }
    if (target == path) return path;
    if (await FileSystemEntity.type(target) != FileSystemEntityType.notFound) {
      throw const FileSystemException('Un élément du même nom existe déjà.');
    }
    final renamed = isDir
        ? await Directory(path).rename(target)
        : await File(path).rename(target);
    await _metadata.move(path, renamed.path);
    return renamed.path;
  }

  // --- Favorites / tags ------------------------------------------------------

  Future<void> setFavorite(String path, bool value) =>
      _metadata.setFavorite(path, value);

  Future<void> setTags(String path, List<String> tags) =>
      _metadata.setTags(path, tags);

  // --- Move / duplicate ------------------------------------------------------

  Future<String> move(String path, String destDir) async {
    final target = _uniquePath(p.join(destDir, p.basename(path)));
    final isDir = await FileSystemEntity.isDirectory(path);
    final result = isDir
        ? await Directory(path).rename(target)
        : await File(path).rename(target);
    await _metadata.move(path, result.path);
    return result.path;
  }

  Future<String> duplicate(String path) async {
    final parent = p.dirname(path);
    final isDir = await FileSystemEntity.isDirectory(path);
    if (isDir) {
      final target = _uniquePath(p.join(parent, '${p.basename(path)} (copie)'));
      await _copyDirectory(path, target);
      return target;
    }
    final base = p.basenameWithoutExtension(path);
    final ext = p.extension(path);
    final target = _uniquePath(p.join(parent, '$base (copie)$ext'));
    await File(path).copy(target);
    return target;
  }

  // --- Import (copy into the workspace) --------------------------------------

  /// Copies files/folders into [destDir]. Continues on individual failures and
  /// returns the list of paths that failed.
  Future<List<String>> importPaths(
      String destDir, List<String> sourcePaths) async {
    final failed = <String>[];
    for (final src in sourcePaths) {
      try {
        final type = await FileSystemEntity.type(src);
        switch (type) {
          case FileSystemEntityType.directory:
            await _copyDirectory(src, p.join(destDir, p.basename(src)));
          case FileSystemEntityType.file:
            await _copyFileInto(destDir, src);
          default:
            // Missing, a link, or otherwise not something we can copy.
            failed.add(src);
        }
      } catch (_) {
        failed.add(src);
      }
    }
    return failed;
  }

  Future<void> _copyFileInto(String destDir, String srcPath) async {
    final name = p.basename(srcPath);
    final target = _uniquePath(p.join(destDir, name));
    await File(srcPath).copy(target);
  }

  Future<void> _copyDirectory(String srcDir, String destDir) async {
    final target = _uniquePath(destDir);
    await Directory(target).create(recursive: true);
    await for (final ent in Directory(srcDir).list(followLinks: false)) {
      final name = p.basename(ent.path);
      if (ent is Directory) {
        await _copyDirectory(ent.path, p.join(target, name));
      } else if (ent is File) {
        await ent.copy(p.join(target, name));
      }
    }
  }

  // --- Trash -----------------------------------------------------------------

  Future<void> moveToTrash(String path) async {
    final isDir = await FileSystemEntity.isDirectory(path);
    final id = _uuid.v4();
    final name = p.basename(path);
    await _trash.trashDir.create(recursive: true);
    final trashedPath = p.join(_trash.trashDir.path, '${id}__$name');
    if (isDir) {
      await Directory(path).rename(trashedPath);
    } else {
      await File(path).rename(trashedPath);
    }
    await _trash.add(TrashEntry(
      id: id,
      name: name,
      originalPath: path,
      trashedPath: trashedPath,
      isDir: isDir,
      deletedAt: DateTime.now(),
    ));
  }

  Future<List<TrashEntry>> listTrash() => _trash.list();

  Future<void> restoreFromTrash(String id) async {
    final entry = await _trash.find(id);
    if (entry == null) return;
    // Restore to the original location, or to the workspace root if the
    // original parent no longer exists.
    var target = entry.originalPath;
    if (!await Directory(p.dirname(target)).exists()) {
      target = p.join(root, entry.name);
    }
    target = _uniquePath(target);
    if (entry.isDir) {
      await Directory(entry.trashedPath).rename(target);
    } else {
      await File(entry.trashedPath).rename(target);
    }
    await _trash.remove(id);
  }

  Future<void> deleteForever(String id) async {
    final entry = await _trash.find(id);
    if (entry == null) return;
    final type = await FileSystemEntity.type(entry.trashedPath);
    if (type == FileSystemEntityType.directory) {
      await Directory(entry.trashedPath).delete(recursive: true);
    } else if (type == FileSystemEntityType.file) {
      await File(entry.trashedPath).delete();
    }
    await _trash.remove(id);
  }

  Future<void> emptyTrash() async {
    for (final entry in await _trash.list()) {
      await deleteForever(entry.id);
    }
  }

  // --- Helpers ---------------------------------------------------------------

  bool _exists(String path) =>
      File(path).existsSync() || Directory(path).existsSync();

  /// Returns [path] or, if it already exists, an incremented variant so nothing
  /// is overwritten.
  String _uniquePath(String path) {
    if (!_exists(path)) return path;
    final dir = p.dirname(path);
    final ext = p.extension(path);
    final base = p.basenameWithoutExtension(path);
    var i = 1;
    while (true) {
      final candidate = p.join(dir, '$base ($i)$ext');
      if (!_exists(candidate)) return candidate;
      i++;
    }
  }

  String _sanitize(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'Sans titre' : cleaned;
  }
}
