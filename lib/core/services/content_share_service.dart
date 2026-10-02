import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../features/library/domain/library_entry.dart';

/// What happened when the user asked to share. Clipboard can only tell that the
/// system share sheet was opened/closed, never that something was published.
enum ShareOutcome {
  /// The share sheet was launched (or the target app took the content).
  success,

  /// The user closed the share sheet without choosing a target.
  dismissed,

  /// No text and no media: nothing to share.
  noContent,

  /// Media were requested but none of them is usable.
  noValidFiles,

  /// Valid images AND videos: the caller must ask which kind to share.
  mixedMediaNeedsChoice,

  /// Another share is already being prepared / shown.
  busy,

  /// The native layer threw.
  failure,
}

class ShareResult {
  const ShareResult(
    this.outcome, {
    this.skipped = 0,
    this.images = const [],
    this.videos = const [],
  });

  final ShareOutcome outcome;

  /// Media paths ignored (missing, unreadable or unsupported kind).
  final int skipped;

  /// Only filled for [ShareOutcome.mixedMediaNeedsChoice].
  final List<String> images;
  final List<String> videos;
}

/// Result reported by the native share layer.
enum ShareGatewayStatus { success, dismissed, unknown }

/// Thin seam over the share plugin so the logic is testable without a device.
abstract class ShareGateway {
  Future<ShareGatewayStatus> share({
    String? text,
    String? title,
    List<ShareFile> files = const [],
    Rect? origin,
  });
}

class ShareFile {
  const ShareFile(this.path, this.name, this.mimeType);
  final String path;
  final String name;
  final String mimeType;
}

class SharePlusGateway implements ShareGateway {
  const SharePlusGateway();

  @override
  Future<ShareGatewayStatus> share({
    String? text,
    String? title,
    List<ShareFile> files = const [],
    Rect? origin,
  }) async {
    final xFiles = [
      for (final f in files) XFile(f.path, name: f.name, mimeType: f.mimeType),
    ];
    final result = await SharePlus.instance.share(
      ShareParams(
        text: text,
        title: title,
        subject: text == null ? null : title,
        files: xFiles.isEmpty ? null : xFiles,
        fileNameOverrides:
            xFiles.isEmpty ? null : [for (final f in files) f.name],
        previewThumbnail: xFiles.isEmpty ? null : xFiles.first,
        sharePositionOrigin: origin,
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => ShareGatewayStatus.success,
      ShareResultStatus.dismissed => ShareGatewayStatus.dismissed,
      ShareResultStatus.unavailable => ShareGatewayStatus.unknown,
    };
  }
}

/// Returns the text exactly as written (line breaks, emoji, hashtags, links
/// untouched), or null when it is empty / whitespace only.
String? buildShareText(String? text) =>
    text == null || text.trim().isEmpty ? null : text;

/// Splits [paths] into images, videos and the number of unsupported entries.
({List<String> images, List<String> videos, int unsupported}) classifyMedia(
  Iterable<String> paths,
) {
  final images = <String>[];
  final videos = <String>[];
  var unsupported = 0;
  for (final path in paths) {
    switch (kindForFile(path)) {
      case EntryKind.image:
        images.add(path);
      case EntryKind.video:
        videos.add(path);
      default:
        unsupported++;
    }
  }
  return (images: images, videos: videos, unsupported: unsupported);
}

/// MIME type for a media path; the generic fallback is never used for
/// classified media.
String shareMimeType(String path) {
  switch (p.extension(path).toLowerCase()) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.gif':
      return 'image/gif';
    case '.webp':
      return 'image/webp';
    case '.bmp':
      return 'image/bmp';
    case '.heic':
      return 'image/heic';
    case '.heif':
      return 'image/heif';
    case '.tif':
    case '.tiff':
      return 'image/tiff';
    case '.svg':
      return 'image/svg+xml';
    case '.avif':
      return 'image/avif';
    case '.ico':
      return 'image/x-icon';
    case '.mp4':
    case '.m4v':
      return 'video/mp4';
    case '.mov':
      return 'video/quicktime';
    case '.webm':
      return 'video/webm';
    case '.3gp':
      return 'video/3gpp';
    case '.avi':
      return 'video/x-msvideo';
    case '.mkv':
      return 'video/x-matroska';
    default:
      return 'application/octet-stream';
  }
}

class ContentShareService {
  ContentShareService({
    ShareGateway gateway = const SharePlusGateway(),
    Future<bool> Function(String path)? fileExists,
  })  : _gateway = gateway,
        _fileExists = fileExists ?? ((path) => File(path).exists());

  final ShareGateway _gateway;
  final Future<bool> Function(String path) _fileExists;
  bool _busy = false;

  /// Opens the native share sheet with [text] and the valid files among
  /// [localMediaPaths]. Images mixed with videos are never sent together:
  /// [ShareOutcome.mixedMediaNeedsChoice] is returned with both lists so the
  /// caller can call again with only one of them.
  Future<ShareResult> shareContent({
    required String? text,
    required List<String> localMediaPaths,
    String? title,
    Rect? origin,
  }) async {
    if (_busy) return const ShareResult(ShareOutcome.busy);
    _busy = true;
    try {
      final shareText = buildShareText(text);
      if (shareText == null && localMediaPaths.isEmpty) {
        return const ShareResult(ShareOutcome.noContent);
      }

      final valid = <String>[];
      var skipped = 0;
      for (final path in localMediaPaths) {
        if (path.trim().isNotEmpty && await _safeExists(path)) {
          valid.add(path);
        } else {
          skipped++;
        }
      }
      final media = classifyMedia(valid);
      skipped += media.unsupported;

      final usable = media.images.length + media.videos.length;
      if (localMediaPaths.isNotEmpty && usable == 0) {
        return ShareResult(ShareOutcome.noValidFiles, skipped: skipped);
      }
      if (media.images.isNotEmpty && media.videos.isNotEmpty) {
        return ShareResult(
          ShareOutcome.mixedMediaNeedsChoice,
          skipped: skipped,
          images: media.images,
          videos: media.videos,
        );
      }

      final files = [
        for (final path in [...media.images, ...media.videos])
          ShareFile(path, p.basename(path), shareMimeType(path)),
      ];
      final status = await _gateway.share(
        text: shareText,
        title: title,
        files: files,
        origin: origin,
      );
      return ShareResult(
        status == ShareGatewayStatus.dismissed
            ? ShareOutcome.dismissed
            : ShareOutcome.success,
        skipped: skipped,
      );
    } catch (error, stack) {
      developer.log(
        'Share failed',
        name: 'ContentShareService',
        error: error,
        stackTrace: stack,
      );
      return const ShareResult(ShareOutcome.failure);
    } finally {
      _busy = false;
    }
  }

  Future<bool> _safeExists(String path) async {
    try {
      return await _fileExists(path);
    } catch (_) {
      return false;
    }
  }
}
