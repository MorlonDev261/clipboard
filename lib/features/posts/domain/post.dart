import 'package:meta/meta.dart';

import '../../../shared/enums/enums.dart';

/// A complete social-media publication, composed of a caption, hashtags,
/// target platforms and an ordered list of media asset ids.
@immutable
class Post {
  const Post({
    required this.id,
    required this.folderId,
    required this.title,
    required this.caption,
    required this.mediaAssetIds,
    required this.hashtags,
    required this.platforms,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.scheduledAt,
    this.publishedAt,
  });

  final String id;
  final String folderId;
  final String title;
  final String caption;
  final List<String> mediaAssetIds;
  final List<String> hashtags;
  final List<String> platforms;
  final PostStatus status;
  final DateTime? scheduledAt;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) => other is Post && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
