import 'dart:convert';
import 'dart:typed_data';

import '../../domain/clean_options.dart';
import '../../domain/clean_report.dart';
import '../binary.dart';
import '../exif_inspector.dart';
import '../format_handler.dart';

class _Chunk {
  _Chunk(this.type, this.start, this.end);

  final String type;
  final int start; // length field
  final int end; // exclusive, after CRC

  int get dataStart => start + 8;
  int get dataEnd => end - 4;
}

/// PNG: allowlist of rendering chunks. Text chunks (incl. Stable-Diffusion
/// style prompts), `tIME`, `eXIf`, XMP, C2PA (`caBX`) and unknown ancillary
/// chunks are dropped, as is any data after `IEND`.
class PngHandler extends ByteFormatHandler {
  const PngHandler();

  static const _signature = [137, 80, 78, 71, 13, 10, 26, 10];

  static const _essential = {
    'IHDR', 'PLTE', 'IDAT', 'IEND', 'tRNS', 'gAMA', 'cHRM', 'sRGB', 'sBIT',
    'bKGD', 'hIST', 'pHYs', 'sPLT', 'acTL', 'fcTL', 'fdAT', 'cICP', 'mDCv',
    'cLLi', //
  };

  @override
  MediaFormat get format => MediaFormat.png;

  @override
  HandlerResult process(
    Uint8List b,
    CleanOptions options,
    BytesBuilder? out,
  ) {
    if (b.length < 8) throw const FormatException('Not a PNG');
    for (var i = 0; i < 8; i++) {
      if (b[i] != _signature[i]) throw const FormatException('Not a PNG');
    }
    final chunks = <_Chunk>[];
    var offset = 8;
    var trailing = 0;
    var sawEnd = false;
    while (offset + 12 <= b.length) {
      final length = u32be(b, offset);
      final end = offset + 12 + length;
      if (end > b.length) throw const FormatException('Truncated PNG chunk');
      final type = fourcc(b, offset + 4);
      chunks.add(_Chunk(type, offset, end));
      offset = end;
      if (type == 'IEND') {
        sawEnd = true;
        trailing = b.length - end;
        break;
      }
    }
    if (!sawEnd) throw const FormatException('PNG has no IEND chunk');

    final findings = <MetadataFinding>[];
    if (trailing > 0) {
      findings.add(MetadataFinding(
        MetadataCategory.trailingData,
        'data after IEND',
        bytes: trailing,
      ));
    }

    final keep = <_Chunk>[];
    int? orientation;
    for (final c in chunks) {
      final size = c.end - c.start;
      if (_essential.contains(c.type)) {
        keep.add(c);
      } else if (c.type == 'iCCP') {
        findings.add(MetadataFinding(
            MetadataCategory.colorProfile, 'ICC profile',
            bytes: size, sensitive: false));
        if (options.keepColorProfile) keep.add(c);
      } else if (c.type == 'eXIf') {
        final info = ExifInspector.inspect(b, c.dataStart, c.dataEnd);
        orientation ??= info.orientation;
        for (final e in info.findings) {
          findings.add(e.copyWith(bytes: e.sensitive ? size : 0));
        }
      } else if (c.type == 'tEXt' || c.type == 'zTXt' || c.type == 'iTXt') {
        final keyword = _keyword(b, c.dataStart, c.dataEnd);
        final isXmp = keyword == 'XML:com.adobe.xmp';
        findings.add(MetadataFinding(
          isXmp ? MetadataCategory.xmp : MetadataCategory.comment,
          isXmp ? 'XMP' : '${c.type} "$keyword"',
          bytes: size,
          entries: [
            MetadataEntry(
              isXmp ? 'XMP' : keyword,
              isXmp ? sizeLabel(size) : _textValue(b, c),
            ),
          ],
        ));
      } else if (c.type == 'tIME') {
        findings.add(MetadataFinding(MetadataCategory.dateTime, 'tIME',
            bytes: size, entries: [MetadataEntry('tIME', _time(b, c))]));
      } else if (c.type == 'caBX') {
        findings.add(MetadataFinding(
            MetadataCategory.provenance, 'C2PA manifest (caBX)',
            bytes: size,
            entries: [MetadataEntry('C2PA manifest', sizeLabel(size))]));
      } else if (c.type.codeUnitAt(0) & 0x20 == 0) {
        throw FormatException('Unknown critical PNG chunk ${c.type}');
      } else {
        findings.add(MetadataFinding(MetadataCategory.container, c.type,
            bytes: size,
            entries: [MetadataEntry('Chunk ${c.type}', sizeLabel(size))]));
      }
    }

    if (out != null) {
      final exifOrientation =
          options.preserveOrientation && orientation != null && orientation > 1
              ? orientation
              : null;
      out.add(b.sublist(0, 8));
      var exifWritten = exifOrientation == null;
      for (final c in keep) {
        // eXIf must precede the first IDAT.
        if (!exifWritten && c.type == 'IDAT') {
          out.add(_exifChunk(exifOrientation!));
          exifWritten = true;
        }
        out.add(b.sublist(c.start, c.end));
      }
    }
    return HandlerResult(findings);
  }

  static String _time(Uint8List b, _Chunk c) {
    final d = c.dataStart;
    if (c.dataEnd - d < 7) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u16be(b, d)}-${two(b[d + 2])}-${two(b[d + 3])} '
        '${two(b[d + 4])}:${two(b[d + 5])}:${two(b[d + 6])}';
  }

  /// Text of a tEXt / iTXt chunk (compressed variants are only labelled).
  static String _textValue(Uint8List b, _Chunk c) {
    var k = c.dataStart;
    while (k < c.dataEnd && b[k] != 0) {
      k++;
    }
    k++; // after the keyword's NUL
    if (c.type == 'tEXt') {
      return k >= c.dataEnd ? '' : latin1Text(b, k, c.dataEnd);
    }
    if (c.type == 'zTXt') return '<compressed text>';
    if (k + 2 > c.dataEnd) return '';
    if (b[k] == 1) return '<compressed text>';
    k += 2; // flag + method
    for (var nul = 0; nul < 2 && k < c.dataEnd; k++) {
      if (b[k] == 0) nul++; // language tag, translated keyword
    }
    return k >= c.dataEnd ? '' : utf8Text(b, k, c.dataEnd);
  }

  static String _keyword(Uint8List b, int start, int end) {
    var e = start;
    while (e < end && e - start < 80 && b[e] != 0) {
      e++;
    }
    return latin1
        .decode(b.sublist(start, e))
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
  }

  static Uint8List _exifChunk(int orientation) {
    final tiff = ExifInspector.minimalTiff(orientation);
    final typeAndData = BytesBuilder(copy: false)
      ..add(ascii4('eXIf'))
      ..add(tiff);
    final td = typeAndData.takeBytes();
    return (BytesBuilder(copy: false)
          ..add(be32(tiff.length))
          ..add(td)
          ..add(be32(crc32(td))))
        .takeBytes();
  }
}
