import 'dart:convert';
import 'dart:typed_data';

import '../../../domain/clean_report.dart';
import '../../binary.dart';
import 'iso_node.dart';

/// Reads the human-visible content of QuickTime / iTunes metadata containers
/// (`udta`, `meta` with `keys` + `ilst`) so the report can show *what* was
/// removed: `©xyz` GPS, `com.apple.quicktime.make`, creation date…
class IsoMetaReader {
  const IsoMetaReader._();

  /// [payload] is the box content without its 8-byte header.
  static List<MetadataEntry> read(String type, Uint8List payload) {
    try {
      return type == 'udta' ? _udta(payload) : _meta(payload);
    } catch (_) {
      return const [];
    }
  }

  static String _pretty(String name) =>
      name.replaceFirst('com.apple.quicktime.', '');

  static List<MetadataEntry> _udta(Uint8List d) {
    final out = <MetadataEntry>[];
    for (final c in IsoNode.parse(d)) {
      final p = c.data!;
      if (c.type == 'meta') {
        out.addAll(_meta(p));
      } else if (p.length >= 4 &&
          u16be(p, 0) > 0 &&
          u16be(p, 0) <= p.length - 4) {
        out.add(
            MetadataEntry(_pretty(c.type), utf8Text(p, 4, 4 + u16be(p, 0))));
      } else {
        out.add(MetadataEntry(_pretty(c.type), sizeLabel(p.length)));
      }
    }
    return out;
  }

  static List<MetadataEntry> _meta(Uint8List d) {
    // QuickTime `meta` is a plain box; ISO `meta` is a FullBox (4 bytes first).
    final skip = d.length >= 8 && fourcc(d, 4) == 'hdlr' ? 0 : 4;
    final kids = IsoNode.parse(d, skip);
    final keys = <String>[];
    final keysBox = IsoNode.find(kids, 'keys')?.data;
    if (keysBox != null && keysBox.length >= 8) {
      var o = 8;
      final n = u32be(keysBox, 4);
      for (var i = 0; i < n && o + 8 <= keysBox.length; i++) {
        final size = u32be(keysBox, o);
        if (size < 8 || o + size > keysBox.length) break;
        keys.add(utf8.decode(keysBox.sublist(o + 8, o + size),
            allowMalformed: true));
        o += size;
      }
    }
    final out = <MetadataEntry>[];
    final ilst = IsoNode.find(kids, 'ilst')?.data;
    if (ilst == null) return out;
    for (final item in IsoNode.parse(ilst)) {
      final data = IsoNode.find(IsoNode.parse(item.data!), 'data')?.data;
      if (data == null || data.length < 8) continue;
      // With a `keys` box the item "type" is the 1-based key index.
      final index = item.rawType ?? 0;
      final name = keys.isNotEmpty && index >= 1 && index <= keys.length
          ? keys[index - 1]
          : item.type;
      out.add(MetadataEntry(_pretty(name), _value(data)));
    }
    return out;
  }

  static String _value(Uint8List d) {
    final type = u32be(d, 0) & 0xFFFFFF;
    final v = d.sublist(8);
    switch (type) {
      case 1:
        return utf8Text(v, 0, v.length);
      case 21:
      case 22:
        var n = 0;
        for (final b in v) {
          n = (n << 8) | b;
        }
        return '$n';
      default:
        return v.length <= 12
            ? v.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')
            : '<${v.length} bytes>';
    }
  }
}
