import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// The kind of a filesystem entry, inferred from whether it is a directory and,
/// for files, from the extension.
enum EntryKind { folder, note, image, video, other }

/// A single entry in the library: a real folder or file on disk, enriched with
/// sidecar metadata (favorite, tags).
@immutable
class LibraryEntry {
  const LibraryEntry({
    required this.path,
    required this.name,
    required this.kind,
    required this.size,
    required this.modified,
    this.isFavorite = false,
    this.tags = const [],
  });

  /// Absolute path on disk.
  final String path;

  /// File or folder name (basename).
  final String name;

  final EntryKind kind;

  /// Size in bytes (0 for folders).
  final int size;

  final DateTime modified;

  final bool isFavorite;
  final List<String> tags;

  bool get isFolder => kind == EntryKind.folder;
  bool get isNote => kind == EntryKind.note;
  bool get isImage => kind == EntryKind.image;
  bool get isVideo => kind == EntryKind.video;
  bool get isMedia => isImage || isVideo;

  /// Display name without the `.md` extension for notes.
  String get displayName =>
      isNote ? p.basenameWithoutExtension(name) : name;

  @override
  bool operator ==(Object other) => other is LibraryEntry && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// File extensions recognised as images and videos.
const imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'};
const videoExtensions = {'.mp4', '.mov', '.webm', '.avi', '.mkv', '.m4v'};
const noteExtensions = {'.md', '.markdown', '.txt'};

/// Classifies a file (not a directory) by its extension.
EntryKind kindForFile(String fileName) {
  final ext = p.extension(fileName).toLowerCase();
  if (imageExtensions.contains(ext)) return EntryKind.image;
  if (videoExtensions.contains(ext)) return EntryKind.video;
  if (noteExtensions.contains(ext)) return EntryKind.note;
  return EntryKind.other;
}
