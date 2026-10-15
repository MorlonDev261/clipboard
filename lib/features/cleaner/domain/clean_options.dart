class CleanOptions {
  const CleanOptions({
    this.preserveOrientation = true,
    this.keepColorProfile = true,
    this.bakeOrientation = false,
  });

  /// Removes every optional block, like online EXIF removers: no orientation
  /// flag, no ICC profile, and the rotation applied to the pixels instead.
  static const stripAll = CleanOptions(
    preserveOrientation: false,
    keepColorProfile: false,
    bakeOrientation: true,
  );

  /// Stripping EXIF also drops the rotation flag, so a portrait photo would
  /// show up sideways. When true, a minimal EXIF block holding only the
  /// orientation value (no identifying data) is written back.
  final bool preserveOrientation;

  /// Keep the embedded ICC colour profile (needed for correct colours on
  /// wide-gamut photos). Profiles describe colour spaces, not people.
  final bool keepColorProfile;

  /// Apply the EXIF rotation to the image data itself (lossless for JPEG: DCT
  /// coefficients are rearranged, nothing is re-compressed) so no orientation
  /// flag is needed. Where that is not possible the flag is kept, as with
  /// [preserveOrientation], and the report says so for JPEG.
  final bool bakeOrientation;

  /// Whether a handler that cannot rotate pixels must keep the orientation
  /// flag so the picture is not shown sideways.
  bool get keepOrientationFlag => preserveOrientation || bakeOrientation;
}
