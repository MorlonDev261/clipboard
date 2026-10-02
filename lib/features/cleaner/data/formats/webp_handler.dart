import 'dart:typed_data';

import '../../domain/clean_options.dart';
import '../../domain/clean_report.dart';
import '../binary.dart';
import '../exif_inspector.dart';
import '../format_handler.dart';

class _Chunk {
  _Chunk(this.type, this.start, this.dataStart, this.dataEnd, this.end);

  final String type;
  final int start;
  final int dataStart;
  final int dataEnd;
  final int end; // padded
}

/// WebP (RIFF): keeps image/animation chunks, drops `EXIF`, `XMP ` and unknown
/// chunks, and rewrites the `VP8X` feature flags so they match what is left.
class WebpHandler extends ByteFormatHandler {
  const WebpHandler();

  static const _essential = {'VP8 ', 'VP8L', 'VP8X', 'ALPH', 'ANIM', 'ANMF'};

  // VP8X flag bits.
  static const _flagIcc = 0x20;
  static const _flagExif = 0x08;
  static const _flagXmp = 0x04;

  @override
  MediaFormat get format => MediaFormat.webp;

  @override
  HandlerResult process(
    Uint8List b,
    CleanOptions options,
    BytesBuilder? out,
  ) {
    if (b.length < 12 ||
        !startsWithAscii(b, 0, 'RIFF') ||
        !startsWithAscii(b, 8, 'WEBP')) {
      throw const FormatException('Not a WebP');
    }
    final declared = u32le(b, 4) + 8;
    final fileEnd = declared < b.length ? declared : b.length;
    final findings = <MetadataFinding>[];
    if (b.length > declared) {
      findings.add(MetadataFinding(
          MetadataCategory.trailingData, 'data after RIFF',
          bytes: b.length - declared));
    }

    final chunks = <_Chunk>[];
    var offset = 12;
    while (offset + 8 <= fileEnd) {
      final type = fourcc(b, offset);
      final size = u32le(b, offset + 4);
      final dataStart = offset + 8;
      final dataEnd = dataStart + size;
      final end = dataEnd + (size.isOdd ? 1 : 0);
      if (dataEnd > fileEnd) throw const FormatException('Truncated WebP');
      chunks.add(_Chunk(type, offset, dataStart, dataEnd, end));
      offset = end > fileEnd ? fileEnd : end;
    }

    final keep = <_Chunk>[];
    int? orientation;
    var hasIcc = false;
    for (final c in chunks) {
      final size = c.end - c.start;
      if (_essential.contains(c.type)) {
        keep.add(c);
      } else if (c.type == 'ICCP') {
        findings.add(MetadataFinding(
            MetadataCategory.colorProfile, 'ICC profile',
            bytes: size, sensitive: false));
        if (options.keepColorProfile) {
          keep.add(c);
          hasIcc = true;
        }
      } else if (c.type == 'EXIF') {
        // Some writers prefix the TIFF block with "Exif\0\0".
        final skip =
            startsWithAscii(b, c.dataStart, 'Exif\u0000\u0000') ? 6 : 0;
        final info = ExifInspector.inspect(b, c.dataStart + skip, c.dataEnd);
        orientation ??= info.orientation;
        for (final e in info.findings) {
          findings.add(e.copyWith(bytes: e.sensitive ? size : 0));
        }
      } else if (c.type == 'XMP ') {
        findings.add(MetadataFinding(MetadataCategory.xmp, 'XMP', bytes: size));
      } else {
        findings.add(
            MetadataFinding(MetadataCategory.container, c.type, bytes: size));
      }
    }

    if (out != null) {
      final hasVp8x = keep.any((c) => c.type == 'VP8X');
      final exifOrientation = hasVp8x &&
              options.preserveOrientation &&
              orientation != null &&
              orientation > 1
          ? orientation
          : null;
      final body = BytesBuilder(copy: false);
      for (final c in keep) {
        if (c.type == 'VP8X') {
          final head = Uint8List.fromList(b.sublist(c.start, c.end));
          var flags = head[8];
          flags &= ~(_flagIcc | _flagExif | _flagXmp);
          if (hasIcc) flags |= _flagIcc;
          if (exifOrientation != null) flags |= _flagExif;
          head[8] = flags;
          body.add(head);
        } else {
          body.add(b.sublist(c.start, c.end));
        }
      }
      if (exifOrientation != null) {
        final tiff = ExifInspector.minimalTiff(exifOrientation);
        body
          ..add(ascii4('EXIF'))
          ..add(le32(tiff.length))
          ..add(tiff);
      }
      final bytes = body.takeBytes();
      out
        ..add(ascii4('RIFF'))
        ..add(le32(bytes.length + 4))
        ..add(ascii4('WEBP'))
        ..add(bytes);
    }
    return HandlerResult(findings);
  }
}
