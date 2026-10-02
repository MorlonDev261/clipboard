import 'dart:typed_data';

import '../../domain/clean_options.dart';
import '../../domain/clean_report.dart';
import '../exif_inspector.dart';
import '../format_handler.dart';
import '../unsupported_content.dart';

/// Classic TIFF. Every IFD (page) is rewritten **in place** keeping only the
/// tags that describe the pixels (allowlist); all offsets stay valid because
/// nothing moves — removed entries are squeezed out of the IFD, and the bytes
/// of their out-of-line values and of the Exif / GPS sub-IFDs are zeroed.
///
/// RAW formats built on TIFF (DNG, CR2, NEF, ARW…) need their maker data to be
/// decodable, so they are refused rather than damaged.
class TiffHandler extends ByteFormatHandler {
  const TiffHandler();

  static const _keep = {
    254, 255, 256, 257, 258, 259, 262, 263, 264, 265, 266, 273, 274, 277, 278,
    279, 280, 281, 282, 283, 284, 296, 297, 301, 317, 318, 319, 320, 321, 322,
    323, 324, 325, 332, 333, 334, 336, 337, 338, 339, 340, 341, 342, 347, 512,
    513, 514, 515, 517, 518, 519, 520, 521, 529, 530, 531, 532, 34675, //
  };

  /// Tags of IFD0 that `ExifInspector` already reports with their values.
  static const _inspected = {
    270, 271, 272, 305, 306, 315, 33432, 34665, 34853, //
  };
  static const _subIfdTags = {34665, 34853, 40965};
  static const _rawTags = {330, 50706, 50707, 50708, 50740};
  static const _typeSize = [0, 1, 1, 2, 4, 8, 1, 1, 2, 4, 8, 4, 8];
  static const _maxBytes = 512 * 1024 * 1024;

  static const _names = <int, (MetadataCategory, String)>{
    270: (MetadataCategory.comment, 'ImageDescription'),
    271: (MetadataCategory.device, 'Make'),
    272: (MetadataCategory.device, 'Model'),
    305: (MetadataCategory.device, 'Software'),
    306: (MetadataCategory.dateTime, 'DateTime'),
    315: (MetadataCategory.comment, 'Artist'),
    316: (MetadataCategory.device, 'HostComputer'),
    269: (MetadataCategory.comment, 'DocumentName'),
    285: (MetadataCategory.comment, 'PageName'),
    33432: (MetadataCategory.comment, 'Copyright'),
    700: (MetadataCategory.xmp, 'XMP'),
    33723: (MetadataCategory.iptc, 'IPTC'),
    34377: (MetadataCategory.iptc, 'Photoshop'),
    34665: (MetadataCategory.exif, 'Exif IFD'),
    34853: (MetadataCategory.gps, 'GPS IFD'),
    33550: (MetadataCategory.gps, 'GeoTIFF'),
    33922: (MetadataCategory.gps, 'GeoTIFF'),
    34735: (MetadataCategory.gps, 'GeoTIFF'),
    34736: (MetadataCategory.gps, 'GeoTIFF'),
    34737: (MetadataCategory.gps, 'GeoTIFF'),
  };

  @override
  MediaFormat get format => MediaFormat.tiff;

  @override
  HandlerResult process(Uint8List b, CleanOptions options, BytesBuilder? out) {
    if (b.length > _maxBytes) {
      throw const UnsupportedContent('TIFF too large to clean in memory');
    }
    if (b.length < 8) throw const FormatException('Not a TIFF');
    final little = b[0] == 0x49 && b[1] == 0x49;
    if (!little && !(b[0] == 0x4D && b[1] == 0x4D)) {
      throw const FormatException('Not a TIFF');
    }
    int u16(int o) {
      if (o < 0 || o + 2 > b.length) throw const FormatException('TIFF offset');
      return little ? b[o] | (b[o + 1] << 8) : (b[o] << 8) | b[o + 1];
    }

    int u32(int o) {
      if (o < 0 || o + 4 > b.length) throw const FormatException('TIFF offset');
      return little
          ? b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)
          : (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
    }

    void put16(Uint8List d, int o, int v) {
      if (little) {
        d[o] = v & 0xFF;
        d[o + 1] = v >> 8;
      } else {
        d[o] = v >> 8;
        d[o + 1] = v & 0xFF;
      }
    }

    final magic = u16(2);
    if (magic == 43) throw const UnsupportedContent('BigTIFF is not supported');
    if (magic != 42) throw const FormatException('Not a TIFF');
    if (b.length > 10 && b[8] == 0x43 && b[9] == 0x52) {
      throw const UnsupportedContent('Canon RAW (CR2) is not supported');
    }

    final copy = Uint8List.fromList(b);
    final findings = <MetadataFinding>[];
    final seen = <int>{};

    int valueBytes(int type, int count) =>
        (type >= 1 && type < _typeSize.length ? _typeSize[type] : 1) * count;

    // Zero an out-of-line value; recurse into sub-IFD pointers.
    void zeroIfd(int off, int depth) {
      if (off == 0 || depth > 3 || !seen.add(off)) return;
      final n = u16(off);
      for (var i = 0; i < n; i++) {
        final e = off + 2 + i * 12;
        final tag = u16(e);
        final type = u16(e + 2);
        final count = u32(e + 4);
        final size = valueBytes(type, count);
        if (_subIfdTags.contains(tag)) zeroIfd(u32(e + 8), depth + 1);
        if (size > 4) {
          final at = u32(e + 8);
          if (at + size <= copy.length) copy.fillRange(at, at + size, 0);
        }
      }
      copy.fillRange(off, off + 2 + n * 12 + 4, 0);
    }

    // Refuse RAW/DNG up front, before anything is rewritten.
    var probe = u32(4);
    var probes = 0;
    while (probe != 0 && probes++ < 1024) {
      final n = u16(probe);
      for (var i = 0; i < n; i++) {
        if (_rawTags.contains(u16(probe + 2 + i * 12))) {
          throw const UnsupportedContent(
              'RAW / DNG files are not supported (export to JPEG or TIFF)');
        }
      }
      probe = u32(probe + 2 + n * 12);
    }

    // IFD0's Exif/GPS/camera tags are reported (with values) by the EXIF
    // inspector; other IFDs and the remaining tags are described tag by tag.
    final info = ExifInspector.inspect(b, 0, b.length, ignore: _keep);
    // IFD1 is the next *page* of a TIFF, not an Exif thumbnail.
    findings.addAll(
        info.findings.where((f) => f.category != MetadataCategory.thumbnail));

    var ifd = u32(4);
    var guard = 0;
    var firstIfd = true;
    while (ifd != 0 && guard++ < 1024) {
      if (!seen.add(ifd)) throw const FormatException('TIFF IFD loop');
      final n = u16(ifd);
      final entriesEnd = ifd + 2 + n * 12;
      final next = u32(entriesEnd);
      final kept = <int>[];
      for (var i = 0; i < n; i++) {
        final e = ifd + 2 + i * 12;
        final tag = u16(e);
        if (_keep.contains(tag)) {
          if (tag == 34675 && !options.keepColorProfile) {
            // dropped below like any other tag
          } else {
            kept.add(e);
            continue;
          }
        }
        final name = _names[tag];
        if (!(firstIfd && _inspected.contains(tag))) {
          findings.add(MetadataFinding(
            name?.$1 ?? MetadataCategory.exif,
            name?.$2 ?? 'tag $tag',
            bytes: 12,
            sensitive: tag != 34675,
            entries: [
              ExifInspector.describe(b, 0, b.length, e, name?.$2 ?? 'tag $tag'),
            ],
          ));
        }
        if (_subIfdTags.contains(tag)) zeroIfd(u32(e + 8), 1);
        final size = valueBytes(u16(e + 2), u32(e + 4));
        if (size > 4) {
          final at = u32(e + 8);
          if (at + size <= copy.length) copy.fillRange(at, at + size, 0);
        }
      }
      if (kept.length != n) {
        final entries = <Uint8List>[
          for (final e in kept) Uint8List.fromList(copy.sublist(e, e + 12)),
        ];
        copy.fillRange(ifd, entriesEnd + 4, 0);
        put16(copy, ifd, kept.length);
        var o = ifd + 2;
        for (final e in entries) {
          copy.setRange(o, o + 12, e);
          o += 12;
        }
        copy.setRange(o, o + 4, b.sublist(entriesEnd, entriesEnd + 4));
      }
      ifd = next;
      firstIfd = false;
    }
    out?.add(copy);
    return HandlerResult(findings);
  }
}
