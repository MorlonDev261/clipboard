/// What kind of personal / identifying data a finding represents.
enum MetadataCategory {
  gps,
  device,
  dateTime,
  exif,
  xmp,
  iptc,
  comment,
  thumbnail,
  provenance,
  timedTrack,
  container,
  trailingData,
  colorProfile,
  orientation,
}

/// Media container formats the cleaner recognises (by magic bytes, never by
/// file extension).
enum MediaFormat {
  jpeg,
  png,
  webp,
  gif,
  avi,
  isoVideo,
  heif,
  matroska,
  pdf,
  tiff,
  unknown,
}

/// One `name = value` pair read from a file (e.g. `Make = Apple`).
class MetadataEntry {
  const MetadataEntry(this.name, this.value);

  final String name;
  final String value;

  @override
  String toString() => '$name=$value';
}

/// One piece of metadata found in (or removed from) a file.
class MetadataFinding {
  const MetadataFinding(
    this.category,
    this.label, {
    this.bytes = 0,
    this.sensitive = true,
    this.entries = const [],
  });

  final MetadataCategory category;

  /// Short technical detail, e.g. `Make, Model` or the PNG text keyword.
  final String label;
  final int bytes;

  /// `false` for data that is kept on purpose and carries no personal
  /// information (orientation, colour profile).
  final bool sensitive;

  /// The actual values, when the format lets us read them. Shown to the user
  /// on screen only; never logged.
  final List<MetadataEntry> entries;

  MetadataFinding copyWith({
    String? label,
    int? bytes,
    bool? sensitive,
    List<MetadataEntry>? entries,
  }) =>
      MetadataFinding(
        category,
        label ?? this.label,
        bytes: bytes ?? this.bytes,
        sensitive: sensitive ?? this.sensitive,
        entries: entries ?? this.entries,
      );

  @override
  String toString() => '${category.name}($label)';
}

/// Known limitations that remain even though nothing sensitive was detected
/// in the output. Surfaced to the user instead of claiming "100 % clean".
enum CleanCaveat {
  /// A video stream uses a codec whose in-stream encoder strings we cannot
  /// inspect (anything but H.264 / HEVC). Container metadata is still clean.
  unsupportedCodecStream,

  /// A Matroska/WebM file embeds attachments (fonts, cover art) that are left
  /// untouched because subtitles may depend on them.
  attachmentsKept,
}

enum CleanStatus {
  /// Re-scanned output contains no sensitive metadata.
  verifiedClean,

  /// Re-scanned output is clean, but [CleanCaveat]s apply.
  cleanedWithCaveats,

  /// The independent re-scan still found sensitive metadata.
  residualFound,

  /// Format not recognised (or not cleanable). No output file is produced.
  unsupported,

  failed,
}

class CleanReport {
  const CleanReport({
    required this.status,
    required this.format,
    this.sourcePath,
    this.outputPath,
    this.before = const [],
    this.after = const [],
    this.caveats = const {},
    this.errorMessage,
  });

  final CleanStatus status;
  final MediaFormat format;
  final String? sourcePath;
  final String? outputPath;

  /// What the original file carried.
  final List<MetadataFinding> before;

  /// What an independent re-scan of the output still finds.
  final List<MetadataFinding> after;
  final Set<CleanCaveat> caveats;
  final String? errorMessage;

  bool get hasOutput => outputPath != null;

  List<MetadataFinding> get removed =>
      before.where((f) => f.sensitive).toList(growable: false);

  List<MetadataFinding> get remaining =>
      after.where((f) => f.sensitive).toList(growable: false);

  bool get isClean =>
      status == CleanStatus.verifiedClean ||
      status == CleanStatus.cleanedWithCaveats;
}
