import 'dart:convert';
import 'dart:typed_data';

import '../domain/clean_report.dart';

class ExifInfo {
  ExifInfo(this.findings, this.orientation);

  final List<MetadataFinding> findings;

  /// EXIF orientation 1–8, if present and valid.
  final int? orientation;
}

/// Reads a TIFF/EXIF block (as found in JPEG APP1, PNG `eXIf`, WebP `EXIF`,
/// HEIC Exif items, or a whole TIFF file) and reports which kinds of personal
/// data it holds, **with their values**. Never throws: a malformed block is
/// reported as one generic sensitive finding.
class ExifInspector {
  const ExifInspector._();

  static const _gpsPointer = 0x8825;
  static const _exifPointer = 0x8769;
  static const _orientation = 0x0112;
  static const _maxValue = 160;

  static const _ifd0 = <int, (MetadataCategory, String)>{
    0x010F: (MetadataCategory.device, 'Make'),
    0x0110: (MetadataCategory.device, 'Model'),
    0x0131: (MetadataCategory.device, 'Software'),
    0x0132: (MetadataCategory.dateTime, 'DateTime'),
    0x013B: (MetadataCategory.exif, 'Artist'),
    0x8298: (MetadataCategory.exif, 'Copyright'),
    0x010E: (MetadataCategory.comment, 'ImageDescription'),
    0x9C9B: (MetadataCategory.comment, 'XPTitle'),
    0x9C9C: (MetadataCategory.comment, 'XPComment'),
    0x9C9D: (MetadataCategory.exif, 'XPAuthor'),
    0x9C9E: (MetadataCategory.comment, 'XPKeywords'),
    0x9C9F: (MetadataCategory.comment, 'XPSubject'),
    0xC4A5: (MetadataCategory.exif, 'PrintIM'),
  };

  static const _exifIfd = <int, (MetadataCategory, String)>{
    0x9003: (MetadataCategory.dateTime, 'DateTimeOriginal'),
    0x9004: (MetadataCategory.dateTime, 'DateTimeDigitized'),
    0x9010: (MetadataCategory.dateTime, 'OffsetTime'),
    0x9011: (MetadataCategory.dateTime, 'OffsetTimeOriginal'),
    0x9291: (MetadataCategory.dateTime, 'SubSecTime'),
    0x927C: (MetadataCategory.device, 'MakerNote'),
    0x9286: (MetadataCategory.comment, 'UserComment'),
    0xA420: (MetadataCategory.device, 'ImageUniqueID'),
    0xA430: (MetadataCategory.exif, 'CameraOwnerName'),
    0xA431: (MetadataCategory.device, 'BodySerialNumber'),
    0xA432: (MetadataCategory.device, 'LensSpecification'),
    0xA433: (MetadataCategory.device, 'LensMake'),
    0xA434: (MetadataCategory.device, 'LensModel'),
    0xA435: (MetadataCategory.device, 'LensSerialNumber'),
  };

  static const _typeSize = [0, 1, 1, 2, 4, 8, 1, 1, 2, 4, 8, 4, 8];

  /// Inspects the TIFF structure in `b[start, end)`.
  ///
  /// [ignore] lists IFD0 tags that are structural (TIFF image layout) and must
  /// not be reported as metadata.
  static ExifInfo inspect(Uint8List b, int start, int end,
      {Set<int> ignore = const {}}) {
    final cats = <MetadataCategory, List<MetadataEntry>>{};
    int? orientation;

    void add(MetadataCategory c, String name, [String value = '']) =>
        (cats[c] ??= <MetadataEntry>[]).add(MetadataEntry(name, value));

    try {
      final r = _Reader(b, start, end);
      final gps = <int, String>{};

      // Returns the offset of the next IFD (0 if none).
      int walk(int ifdOffset, Map<int, (MetadataCategory, String)>? names,
          int kind, int depth) {
        // kind: 0 = IFD0, 1 = Exif IFD, 2 = GPS IFD
        if (depth > 3) return 0;
        final count = r.u16(start + ifdOffset);
        for (var i = 0; i < count; i++) {
          final e = start + ifdOffset + 2 + i * 12;
          final tag = r.u16(e);
          if (kind == 2) {
            gps[tag] = r.value(e);
            continue;
          }
          if (kind == 0 && ignore.contains(tag)) continue;
          if (kind == 0 && tag == _orientation) {
            final v = r.u16(e + 8);
            if (v >= 1 && v <= 8) orientation = v;
            continue;
          }
          if (tag == _gpsPointer) {
            walk(r.u32(e + 8), null, 2, depth + 1);
            continue;
          }
          if (tag == _exifPointer) {
            walk(r.u32(e + 8), _exifIfd, 1, depth + 1);
            continue;
          }
          final known = names![tag];
          if (known != null) {
            add(known.$1, known.$2, r.value(e, tag: tag));
          } else if (tag != 0xA005) {
            // 0xA005 = interoperability pointer: structure only.
            add(MetadataCategory.exif, 'Tag 0x${tag.toRadixString(16)}',
                r.value(e));
          }
        }
        return r.u32(start + ifdOffset + 2 + count * 12);
      }

      final next = walk(r.u32(start + 4), _ifd0, 0, 0);
      if (next != 0) {
        add(MetadataCategory.thumbnail, 'IFD1', 'embedded thumbnail image');
      }
      if (gps.isNotEmpty) {
        cats.remove(MetadataCategory.gps);
        for (final e in _gpsEntries(gps)) {
          add(MetadataCategory.gps, e.name, e.value);
        }
      }
    } catch (_) {
      add(MetadataCategory.exif, 'EXIF', 'unreadable block');
    }

    final findings = <MetadataFinding>[
      for (final e in cats.entries)
        MetadataFinding(
          e.key,
          e.value.map((x) => x.name).toSet().join(', '),
          entries: e.value,
        ),
    ];
    if (orientation != null) {
      findings.add(MetadataFinding(
        MetadataCategory.orientation,
        'Orientation $orientation',
        sensitive: false,
        entries: [MetadataEntry('Orientation', _orientationText(orientation!))],
      ));
    }
    return ExifInfo(findings, orientation);
  }

  static String _orientationText(int o) => switch (o) {
        1 => '1 (normal)',
        3 => '3 (rotated 180°)',
        6 => '6 (rotated 90° clockwise)',
        8 => '8 (rotated 90° counter-clockwise)',
        _ => '$o (mirrored / rotated)',
      };

  /// Human-readable GPS block: decimal coordinates, altitude, date/time.
  static List<MetadataEntry> _gpsEntries(Map<int, String> g) {
    final out = <MetadataEntry>[];
    String? coord(int ref, int val) {
      final v = g[val];
      if (v == null) return null;
      final parts = v.split(' ').map(double.tryParse).toList();
      if (parts.length < 3 || parts.any((p) => p == null)) return v;
      var d = parts[0]! + parts[1]! / 60 + parts[2]! / 3600;
      final r = (g[ref] ?? '').toUpperCase();
      if (r == 'S' || r == 'W') d = -d;
      return '${d.toStringAsFixed(5)}° $r'.trim();
    }

    final lat = coord(1, 2);
    final lon = coord(3, 4);
    if (lat != null) out.add(MetadataEntry('GPS Latitude', lat));
    if (lon != null) out.add(MetadataEntry('GPS Longitude', lon));
    if (g[6] != null) {
      final below = g[5] == '1';
      out.add(MetadataEntry('GPS Altitude', '${below ? '-' : ''}${g[6]} m'));
    }
    if (g[7] != null) out.add(MetadataEntry('GPS Time', g[7]!));
    if (g[29] != null) out.add(MetadataEntry('GPS Date', g[29]!));
    for (final e in g.entries) {
      if ({1, 2, 3, 4, 5, 6, 7, 29}.contains(e.key)) continue;
      out.add(MetadataEntry('GPS tag ${e.key}', e.value));
    }
    if (out.isEmpty) out.add(const MetadataEntry('GPS', 'present'));
    return out;
  }

  /// One entry rendered as `name = value`, for callers that walk IFDs
  /// themselves (TIFF).
  static MetadataEntry describe(
      Uint8List b, int start, int end, int entryOffset, String name) {
    try {
      final r = _Reader(b, start, end);
      return MetadataEntry(name, r.value(entryOffset));
    } catch (_) {
      return MetadataEntry(name, '');
    }
  }

  /// A big-endian TIFF block holding nothing but the orientation tag.
  static Uint8List minimalTiff(int orientation) {
    final b = Uint8List(26);
    b.setRange(0, 4, const [0x4D, 0x4D, 0x00, 0x2A]); // 'MM', 42
    b[7] = 8; // IFD0 offset
    b[9] = 1; // one entry
    b[10] = 0x01;
    b[11] = 0x12; // tag 0x0112
    b[13] = 3; // type SHORT
    b[17] = 1; // count 1
    b[19] = orientation; // SHORT value, left-justified in the 4-byte field
    // next-IFD offset (last 4 bytes) stays 0.
    return b;
  }
}

/// Endian-aware reader over `b[start, end)` that can render an IFD entry's
/// value as text.
class _Reader {
  _Reader(this.b, this.start, this.end) {
    if (end - start < 8) throw const FormatException('short');
    little = b[start] == 0x49 && b[start + 1] == 0x49;
    if (!little && !(b[start] == 0x4D && b[start + 1] == 0x4D)) {
      throw const FormatException('byte order');
    }
  }

  final Uint8List b;
  final int start;
  final int end;
  late final bool little;

  int u16(int o) {
    if (o < start || o + 2 > end) throw const FormatException('oob');
    return little ? b[o] | (b[o + 1] << 8) : (b[o] << 8) | b[o + 1];
  }

  int u32(int o) {
    if (o < start || o + 4 > end) throw const FormatException('oob');
    return little
        ? b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)
        : (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
  }

  int _s32(int o) {
    final v = u32(o);
    return v >= 0x80000000 ? v - 0x100000000 : v;
  }

  /// The value of the 12-byte IFD entry at [e], as short text.
  String value(int e, {int? tag}) {
    final type = u16(e + 2);
    final count = u32(e + 4);
    final size = (type >= 1 && type < ExifInspector._typeSize.length
            ? ExifInspector._typeSize[type]
            : 1) *
        count;
    final at = size <= 4 ? e + 8 : start + u32(e + 8);
    if (size > 0 && (at < start || at + size > end)) return '';
    String clip(String s) => s.length > ExifInspector._maxValue
        ? '${s.substring(0, ExifInspector._maxValue)}…'
        : s;
    switch (type) {
      case 2:
        final bytes = b.sublist(at, at + size);
        var n = bytes.length;
        while (n > 0 && bytes[n - 1] == 0) {
          n--;
        }
        return clip(latin1.decode(bytes.sublist(0, n), allowInvalid: true));
      case 1:
      case 7:
      case 6:
        if (tag == 0x927C || size > 16) return '<$size bytes>';
        final raw = b.sublist(at, at + size);
        final printable = raw.every((c) => c >= 32 && c < 127);
        return printable
            ? latin1.decode(raw)
            : raw.map((c) => c.toRadixString(16).padLeft(2, '0')).join(' ');
      case 3:
      case 8:
        return [
          for (var i = 0; i < count && i < 6; i++) u16(at + 2 * i),
        ].join(' ');
      case 4:
      case 9:
      case 13:
        return [
          for (var i = 0; i < count && i < 6; i++)
            type == 9 ? _s32(at + 4 * i) : u32(at + 4 * i),
        ].join(' ');
      case 5:
      case 10:
        return [
          for (var i = 0; i < count && i < 6; i++)
            _rational(at + 8 * i, signed: type == 10),
        ].join(' ');
      default:
        return '<$size bytes>';
    }
  }

  String _rational(int o, {required bool signed}) {
    final n = signed ? _s32(o) : u32(o);
    final d = signed ? _s32(o + 4) : u32(o + 4);
    if (d == 0) return '0';
    final v = n / d;
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(4);
  }
}
