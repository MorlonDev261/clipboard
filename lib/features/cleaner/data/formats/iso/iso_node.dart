import 'dart:typed_data';

import '../../binary.dart';

/// A parsed ISO-BMFF box. Leaves keep their raw [data]; containers we descend
/// into keep [kids]. Sizes are recomputed on serialisation, so editing a child
/// (or dropping one) is always consistent.
class IsoNode {
  IsoNode(this.type, {this.data, this.kids, this.prefix, this.rawType});

  final String type;

  /// The 4 type bytes as an integer (a `mdta` item's key index lives here).
  final int? rawType;
  Uint8List? data;
  List<IsoNode>? kids;

  /// Bytes between the header and the children (the version/flags of a
  /// FullBox such as `meta`).
  final Uint8List? prefix;

  int get size =>
      8 +
      (prefix?.length ?? 0) +
      (kids != null ? kids!.fold<int>(0, (s, k) => s + k.size) : data!.length);

  void writeTo(BytesBuilder out) {
    out
      ..add(be32(size))
      ..add(ascii4(type));
    if (prefix != null) out.add(prefix!);
    if (kids != null) {
      for (final k in kids!) {
        k.writeTo(out);
      }
    } else {
      out.add(data!);
    }
  }

  Uint8List toBytes() {
    final b = BytesBuilder(copy: false);
    writeTo(b);
    return b.takeBytes();
  }

  /// Shallow parse of the boxes in `b[start, end)`; every node is a leaf.
  static List<IsoNode> parse(Uint8List b, [int start = 0, int? end]) {
    final limit = end ?? b.length;
    final nodes = <IsoNode>[];
    var o = start;
    while (o + 8 <= limit) {
      final size32 = u32be(b, o);
      final type = fourcc(b, o + 4);
      var header = 8;
      int size;
      if (size32 == 1) {
        if (o + 16 > limit) throw const FormatException('Truncated box');
        size = u64be(b, o + 8);
        header = 16;
      } else if (size32 == 0) {
        size = limit - o;
      } else {
        size = size32;
      }
      if (size < header || o + size > limit) {
        throw FormatException('Corrupt child box "$type"');
      }
      nodes.add(IsoNode(type,
          data: b.sublist(o + header, o + size), rawType: u32be(b, o + 4)));
      o += size;
    }
    return nodes;
  }

  static IsoNode? find(List<IsoNode> nodes, String type) {
    for (final n in nodes) {
      if (n.type == type) return n;
    }
    return null;
  }
}
