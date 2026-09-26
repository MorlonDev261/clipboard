import 'package:meta/meta.dart';

/// A folder in the user's content library.
///
/// Folders form a tree via [parentId]. The auto-created top-level folder has
/// [isRoot] set to `true` and must never be deleted.
@immutable
class Folder {
  const Folder({
    required this.id,
    required this.name,
    required this.isRoot,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.path,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String? parentId;
  final String? path;
  final bool isRoot;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Folder copyWith({
    String? name,
    String? Function()? parentId,
    String? Function()? path,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) {
    return Folder(
      id: id,
      name: name ?? this.name,
      parentId: parentId != null ? parentId() : this.parentId,
      path: path != null ? path() : this.path,
      isRoot: isRoot,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) => other is Folder && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
