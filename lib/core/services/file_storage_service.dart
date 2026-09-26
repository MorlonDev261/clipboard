/// Abstraction over platform file operations.
///
/// Concrete implementations (mobile vs desktop) live behind this interface so
/// that no platform-specific logic leaks into the widgets or repositories.
/// The implementation is intentionally deferred to a later milestone; this
/// contract is defined now so the architecture is import-stable.
abstract interface class FileStorageService {
  /// Copies [sourcePath] into the app's private media directory and returns
  /// the new local path.
  Future<String> importFile(String sourcePath, String assetId);

  /// Deletes a previously imported file. Missing files are a no-op.
  Future<void> deleteFile(String localPath);

  /// Generates a thumbnail for [filePath] (image or video), returning its path
  /// or `null` when no thumbnail could be produced.
  Future<String?> createThumbnail(String filePath);

  Future<bool> fileExists(String path);

  Future<int> getFileSize(String path);

  /// Computes a content hash used for duplicate detection.
  Future<String> calculateHash(String path);
}
