/// Business enumerations shared across the domain and data layers.
///
/// These are intentionally kept in one place so that both the Drift tables
/// (data layer) and the domain entities can reference the exact same types
/// without creating a dependency from `core/database` onto a feature layer.
library;

/// The kind of content an [asset] represents.
enum AssetType {
  text,
  image,
  video,
  link,
  post,
}

/// Lifecycle status of an asset.
enum AssetStatus {
  draft,
  ready,
  published,
  archived,
  trashed,
}

/// Lifecycle status of a post.
enum PostStatus {
  draft,
  ready,
  scheduled,
  published,
  archived,
}

/// Presentation mode for content collections.
enum ViewMode {
  grid,
  list,
}

/// Sort orders available across folder and search views.
enum SortOption {
  newest,
  oldest,
  nameAsc,
  nameDesc,
  sizeAsc,
  sizeDesc,
  type,
  lastModified,
}
