import 'dart:typed_data';

import '../domain/clean_report.dart';
import 'binary.dart';

/// Format-agnostic byte search for well-known metadata signatures.
///
/// It deliberately shares no parsing code with the format handlers, so it acts
/// as an independent cross-check on their output: if an XMP packet, an IPTC
/// block or a C2PA manifest is anywhere in the file, this finds it even if a
/// handler's structural walk missed it.
class SignatureScanner {
  const SignatureScanner._();

  static final _xmp = [
    '<x:xmpmeta'.codeUnits,
    'http://ns.adobe.com/xap/1.0/'.codeUnits,
    '<?xpacket begin'.codeUnits,
  ];
  static final _iptc = ['Photoshop 3.0'.codeUnits];
  static final _c2pa = ['c2pa'.codeUnits, 'jumb'.codeUnits];
  static final _exif = [
    [0x45, 0x78, 0x69, 0x66, 0x00, 0x00, 0x4D, 0x4D], // Exif\0\0MM
    [0x45, 0x78, 0x69, 0x66, 0x00, 0x00, 0x49, 0x49], // Exif\0\0II
  ];

  /// Signatures of XMP, IPTC and C2PA. EXIF is reported only when
  /// [includeExif] is set (the minimal orientation block we write back is
  /// legitimately an EXIF block).
  static List<MetadataFinding> scan(
    Uint8List bytes, {
    bool includeExif = false,
  }) {
    final found = <MetadataFinding>[];
    if (_xmp.any((s) => indexOfBytes(bytes, s) >= 0)) {
      found.add(const MetadataFinding(MetadataCategory.xmp, 'XMP (signature)'));
    }
    if (_iptc.any((s) => indexOfBytes(bytes, s) >= 0)) {
      found.add(const MetadataFinding(
          MetadataCategory.iptc, 'IPTC / Photoshop IRB (signature)'));
    }
    // 'jumb' alone is too short to trust; require both C2PA markers.
    if (_c2pa.every((s) => indexOfBytes(bytes, s) >= 0)) {
      found.add(const MetadataFinding(
          MetadataCategory.provenance, 'C2PA manifest (signature)'));
    }
    if (includeExif && _exif.any((s) => indexOfBytes(bytes, s) >= 0)) {
      found.add(
          const MetadataFinding(MetadataCategory.exif, 'EXIF (signature)'));
    }
    return found;
  }
}
