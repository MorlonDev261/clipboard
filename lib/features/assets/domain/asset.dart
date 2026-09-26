import 'package:meta/meta.dart';

import '../../../shared/enums/enums.dart';

/// A single piece of content: text, image, video, link or an embedded post
/// reference. Binary data is never stored in the entity — only the local file
/// path and metadata are kept.
@immutable
class Asset {
  const Asset({
    required this.id,
    required this.folderId,
    required this.name,
    required this.type,
    required this.isFavorite,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.localPath,
    this.thumbnailPath,
    this.mimeType,
    this.fileSize,
    this.durationMs,
    this.textContent,
    this.title,
    this.description,
    this.deletedAt,
    this.fileHash,
  });

  final String id;
  final String folderId;
  final String name;
  final AssetType type;
  final String? localPath;
  final String? thumbnailPath;
  final String? mimeType;
  final int? fileSize;
  final int? durationMs;
  final String? textContent;
  final String? title;
  final String? description;
  final bool isFavorite;
  final AssetStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? fileHash;

  bool get isDeleted => deletedAt != null;
  bool get isMedia => type == AssetType.image || type == AssetType.video;

  @override
  bool operator ==(Object other) => other is Asset && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
