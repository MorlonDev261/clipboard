class CleanOptions {
  const CleanOptions({
    this.preserveOrientation = true,
    this.keepColorProfile = true,
  });

  /// Stripping EXIF also drops the rotation flag, so a portrait photo would
  /// show up sideways. When true, a minimal EXIF block holding only the
  /// orientation value (no identifying data) is written back.
  final bool preserveOrientation;

  /// Keep the embedded ICC colour profile (needed for correct colours on
  /// wide-gamut photos). Profiles describe colour spaces, not people.
  final bool keepColorProfile;
}
