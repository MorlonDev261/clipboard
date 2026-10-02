import 'dart:convert';
import 'dart:typed_data';

import '../../../domain/clean_report.dart';
import '../../binary.dart';
import '../../exif_inspector.dart';
import 'iso_node.dart';
import 'sample_table.dart';

/// Reads bytes of the *source* file (used to inspect Exif items).
typedef SourceReader = Future<Uint8List> Function(int offset, int length);

class _Item {
  _Item(this.id, this.type, this.node, this.contentType);

  final int id;
  final String type;
  final IsoNode node;
  final String contentType;
}

class IlocExtent {
  IlocExtent(this.index, this.offset, this.length);

  final int index;
  int offset;
  final int length;
}

class IlocItem {
  IlocItem(this.id, this.construction, this.dataRef, this.base, this.extents);

  final int id;
  final int construction;
  final int dataRef;
  final int base;
  final List<IlocExtent> extents;
}

/// `iloc`: where every item (image, Exif, XMP…) lives in the file.
class IlocTable {
  IlocTable._(this.version, this.offsetSize, this.lengthSize,
      this.baseOffsetSize, this.indexSize, this.items);

  final int version;
  final int offsetSize;
  final int lengthSize;
  final int baseOffsetSize;
  final int indexSize;
  final List<IlocItem> items;

  static int _read(Uint8List b, int o, int n) {
    var v = 0;
    for (var i = 0; i < n; i++) {
      v = v * 256 + b[o + i];
    }
    return v;
  }

  static void _write(BytesBuilder out, int v, int n) {
    final b = Uint8List(n);
    for (var i = n - 1; i >= 0; i--) {
      b[i] = v & 0xFF;
      v = v ~/ 256;
    }
    out.add(b);
  }

  factory IlocTable.parse(Uint8List d) {
    try {
      final version = d[0];
      final offsetSize = d[4] >> 4;
      final lengthSize = d[4] & 0xF;
      final baseSize = d[5] >> 4;
      final indexSize = version >= 1 ? d[5] & 0xF : 0;
      var o = 6;
      final count = version < 2 ? u16be(d, o) : u32be(d, o);
      o += version < 2 ? 2 : 4;
      final items = <IlocItem>[];
      for (var i = 0; i < count; i++) {
        final id = version < 2 ? u16be(d, o) : u32be(d, o);
        o += version < 2 ? 2 : 4;
        var construction = 0;
        if (version >= 1) {
          construction = u16be(d, o) & 0xF;
          o += 2;
        }
        final dataRef = u16be(d, o);
        o += 2;
        final base = _read(d, o, baseSize);
        o += baseSize;
        final extentCount = u16be(d, o);
        o += 2;
        final extents = <IlocExtent>[];
        for (var e = 0; e < extentCount; e++) {
          var index = 0;
          if (version >= 1 && indexSize > 0) {
            index = _read(d, o, indexSize);
            o += indexSize;
          }
          final off = _read(d, o, offsetSize);
          o += offsetSize;
          final len = _read(d, o, lengthSize);
          o += lengthSize;
          extents.add(IlocExtent(index, off, len));
        }
        items.add(IlocItem(id, construction, dataRef, base, extents));
      }
      return IlocTable._(
          version, offsetSize, lengthSize, baseSize, indexSize, items);
    } on RangeError {
      throw const FormatException('Corrupt iloc box');
    }
  }

  Uint8List serialize() {
    final out = BytesBuilder(copy: false)
      ..add([version, 0, 0, 0])
      ..add([(offsetSize << 4) | lengthSize])
      ..add([(baseOffsetSize << 4) | (version >= 1 ? indexSize : 0)]);
    if (version < 2) {
      out.add(be16(items.length));
    } else {
      out.add(be32(items.length));
    }
    for (final it in items) {
      if (version < 2) {
        out.add(be16(it.id));
      } else {
        out.add(be32(it.id));
      }
      if (version >= 1) out.add(be16(it.construction));
      out.add(be16(it.dataRef));
      _write(out, it.base, baseOffsetSize);
      out.add(be16(it.extents.length));
      for (final e in it.extents) {
        if (version >= 1 && indexSize > 0) _write(out, e.index, indexSize);
        _write(out, e.offset, offsetSize);
        _write(out, e.length, lengthSize);
      }
    }
    return out.takeBytes();
  }

  /// Rebases every file-offset extent through [map] (old → new absolute).
  void remap(int Function(int) map) {
    for (final it in items) {
      if (it.construction != 0) continue;
      for (final e in it.extents) {
        final moved = map(it.base + e.offset) - it.base;
        if (moved < 0) throw const FormatException('iloc offset underflow');
        e.offset = moved;
      }
    }
  }
}

class HeifMetaResult {
  HeifMetaResult(this.meta, this.iloc, this.ilocNode, this.zeroRanges);

  final IsoNode meta;
  final IlocTable? iloc;
  final IsoNode? ilocNode;

  /// Source file ranges holding removed items (Exif / XMP) to blank out.
  final List<ByteRange> zeroRanges;

  void remap(int Function(int) map) {
    if (iloc == null) return;
    iloc!.remap(map);
    ilocNode!.data = iloc!.serialize();
  }
}

/// HEIC / AVIF top-level `meta`: removes the Exif / XMP / URI metadata *items*
/// (from `iinf`, `iloc`, `iref`, `ipma`) and blanks their bytes, keeping the
/// image items, properties (`irot`, `colr`…) and everything the decoder needs.
class HeifMeta {
  const HeifMeta._();

  static const _keep = {
    'hdlr', 'dinf', 'pitm', 'iinf', 'iref', 'iprp', 'iloc', 'idat', 'grpl', //
  };
  static const _metaTypes = {'Exif', 'mime', 'uri '};

  static Future<HeifMetaResult> clean(
    Uint8List payload,
    List<MetadataFinding> findings,
    SourceReader readSource,
  ) async {
    if (payload.length < 4) throw const FormatException('Corrupt meta box');
    final kids = <IsoNode>[];
    for (final k in IsoNode.parse(payload, 4)) {
      if (_keep.contains(k.type)) {
        kids.add(k);
      } else {
        findings.add(MetadataFinding(MetadataCategory.container, k.type,
            bytes: k.data!.length + 8));
      }
    }

    final iinf = IsoNode.find(kids, 'iinf');
    final ilocNode = IsoNode.find(kids, 'iloc');
    final iloc = ilocNode == null ? null : IlocTable.parse(ilocNode.data!);
    final idat = IsoNode.find(kids, 'idat');
    final zero = <ByteRange>[];
    final removed = <int>{};

    if (iinf != null) {
      final items = _parseIinf(iinf.data!);
      final pitm = IsoNode.find(kids, 'pitm');
      for (final it in items.where((i) => _metaTypes.contains(i.type))) {
        removed.add(it.id);
        findings.add(await _describe(it, iloc, idat, readSource));
      }
      if (pitm != null && pitm.data!.length >= 6) {
        final primary =
            pitm.data![0] == 0 ? u16be(pitm.data!, 4) : u32be(pitm.data!, 4);
        if (removed.contains(primary)) {
          throw const FormatException('Primary item is a metadata item');
        }
      }
      if (removed.isNotEmpty) {
        _rewriteIinf(iinf, items, removed);
      }
    }

    if (removed.isNotEmpty) {
      if (iloc != null) {
        final dropped =
            iloc.items.where((i) => removed.contains(i.id)).toList();
        for (final it in dropped) {
          for (final e in it.extents) {
            if (it.construction == 0) {
              zero.add(ByteRange(it.base + e.offset, e.length));
            } else if (it.construction == 1 && idat != null) {
              final copy = Uint8List.fromList(idat.data!);
              final from = it.base + e.offset;
              if (from + e.length > copy.length) {
                throw const FormatException('Item outside idat');
              }
              copy.fillRange(from, from + e.length, 0);
              idat.data = copy;
            } else {
              throw const FormatException('Unsupported item construction');
            }
          }
        }
        iloc.items.removeWhere((i) => removed.contains(i.id));
        ilocNode!.data = iloc.serialize();
      }
      final iref = IsoNode.find(kids, 'iref');
      if (iref != null) _rewriteIref(iref, removed);
      final iprp = IsoNode.find(kids, 'iprp');
      if (iprp != null) _rewriteIprp(iprp, removed);
    }

    final meta = IsoNode('meta',
        prefix: Uint8List.fromList(payload.sublist(0, 4)), kids: kids);
    return HeifMetaResult(meta, iloc, ilocNode, zero);
  }

  static List<_Item> _parseIinf(Uint8List d) {
    final version = d[0];
    final o = 4 + (version == 0 ? 2 : 4);
    final items = <_Item>[];
    for (final infe in IsoNode.parse(d, o)) {
      if (infe.type != 'infe') continue;
      final p = infe.data!;
      final v = p[0];
      if (v < 2) {
        items.add(_Item(u16be(p, 4), '', infe, ''));
        continue;
      }
      final id = v == 2 ? u16be(p, 4) : u32be(p, 4);
      final typeAt = v == 2 ? 8 : 10;
      final type = fourcc(p, typeAt);
      var contentType = '';
      if (type == 'mime') {
        var s = typeAt + 4;
        while (s < p.length && p[s] != 0) {
          s++; // item_name
        }
        var e = ++s;
        while (e < p.length && p[e] != 0) {
          e++;
        }
        if (s <= p.length && e <= p.length) {
          contentType = latin1.decode(p.sublist(s, e), allowInvalid: true);
        }
      }
      items.add(_Item(id, type, infe, contentType));
    }
    return items;
  }

  static void _rewriteIinf(IsoNode iinf, List<_Item> items, Set<int> removed) {
    final d = iinf.data!;
    final version = d[0];
    final keep = items.where((i) => !removed.contains(i.id)).toList();
    final head = BytesBuilder(copy: false)..add([version, d[1], d[2], d[3]]);
    head.add(version == 0 ? be16(keep.length) : be32(keep.length));
    for (final i in keep) {
      i.node.writeTo(head);
    }
    iinf.data = head.takeBytes();
  }

  static void _rewriteIref(IsoNode iref, Set<int> removed) {
    final d = iref.data!;
    final wide = d[0] != 0;
    final out = BytesBuilder(copy: false)..add(d.sublist(0, 4));
    final idSize = wide ? 4 : 2;
    for (final ref in IsoNode.parse(d, 4)) {
      final p = ref.data!;
      final from = wide ? u32be(p, 0) : u16be(p, 0);
      if (removed.contains(from)) continue;
      final count = u16be(p, idSize);
      final to = <int>[
        for (var i = 0; i < count; i++)
          wide ? u32be(p, idSize + 2 + 4 * i) : u16be(p, idSize + 2 + 2 * i),
      ].where((t) => !removed.contains(t)).toList();
      if (to.isEmpty) continue;
      final body = BytesBuilder(copy: false)
        ..add(wide ? be32(from) : be16(from))
        ..add(be16(to.length));
      for (final t in to) {
        body.add(wide ? be32(t) : be16(t));
      }
      IsoNode(ref.type, data: body.takeBytes()).writeTo(out);
    }
    iref.data = out.takeBytes();
  }

  static void _rewriteIprp(IsoNode iprp, Set<int> removed) {
    final kids = IsoNode.parse(iprp.data!);
    for (final k in kids) {
      if (k.type != 'ipma') continue;
      final d = k.data!;
      final version = d[0];
      final big = (d[3] & 1) != 0;
      final count = u32be(d, 4);
      var o = 8;
      final out = BytesBuilder(copy: false);
      var kept = 0;
      for (var i = 0; i < count; i++) {
        final start = o;
        final id = version < 1 ? u16be(d, o) : u32be(d, o);
        o += version < 1 ? 2 : 4;
        final n = d[o++];
        o += n * (big ? 2 : 1);
        if (removed.contains(id)) continue;
        out.add(d.sublist(start, o));
        kept++;
      }
      k.data = (BytesBuilder(copy: false)
            ..add(d.sublist(0, 4))
            ..add(be32(kept))
            ..add(out.takeBytes()))
          .takeBytes();
    }
    iprp.data = kids.fold<BytesBuilder>(BytesBuilder(copy: false), (b, k) {
      k.writeTo(b);
      return b;
    }).takeBytes();
  }

  static Future<MetadataFinding> _describe(
    _Item it,
    IlocTable? iloc,
    IsoNode? idat,
    SourceReader readSource,
  ) async {
    final size = it.node.data!.length;
    if (it.type == 'Exif' && iloc != null) {
      try {
        final loc = iloc.items.firstWhere((i) => i.id == it.id);
        final e = loc.extents.first;
        final from = loc.base + e.offset;
        final len = e.length > (1 << 20) ? (1 << 20) : e.length;
        final bytes = loc.construction == 1 && idat != null
            ? idat.data!.sublist(from, from + len)
            : await readSource(from, len);
        if (bytes.length > 4) {
          final tiff = 4 + u32be(bytes, 0);
          final info = ExifInspector.inspect(bytes, tiff, bytes.length);
          final sens = info.findings.where((f) => f.sensitive).toList();
          if (sens.isNotEmpty) {
            return MetadataFinding(MetadataCategory.exif,
                'Exif item: ${sens.map((f) => f.category.name).join(', ')}',
                bytes: e.length, entries: [for (final f in sens) ...f.entries]);
          }
        }
      } catch (_) {
        // fall through to the generic description
      }
      return MetadataFinding(MetadataCategory.exif, 'Exif item', bytes: size);
    }
    if (it.type == 'mime') {
      final xmp =
          it.contentType.contains('rdf+xml') || it.contentType.contains('xmp');
      return MetadataFinding(
          xmp ? MetadataCategory.xmp : MetadataCategory.container,
          xmp ? 'XMP item' : 'mime item ${it.contentType}',
          bytes: size,
          entries: [
            MetadataEntry(
                xmp ? 'XMP' : 'mime ${it.contentType}', sizeLabel(size))
          ]);
    }
    return MetadataFinding(
        MetadataCategory.container, 'metadata item ${it.type}',
        bytes: size);
  }
}
