import 'dart:typed_data';

import '../binary.dart';

/// One marker segment of a JPEG: `start` is the offset of its 0xFF byte, `end`
/// is exclusive (for SOS it includes the entropy-coded data).
class JpegSegment {
  JpegSegment(this.marker, this.start, this.end);

  final int marker;
  final int start;
  final int end;
}

/// Bakes an EXIF [orientation] (2..8) into a JPEG without decoding pixels:
/// the quantised DCT coefficients are re-arranged (transpose / mirror), which
/// is mathematically exact, then re-entropy-coded with freshly optimised
/// Huffman tables. Returns the structural segments (DQT, SOF, DHT, SOS + scan
/// data, no SOI / EOI / APPn), or `null` when the file cannot be transformed
/// losslessly (progressive, arithmetic, multi-scan, or dimensions that are not
/// a multiple of the MCU along a mirrored axis). The caller then falls back to
/// keeping a minimal orientation flag.
Uint8List? rotateJpegLossless(
  Uint8List b,
  List<JpegSegment> segments,
  int orientation,
) {
  if (orientation < 2 || orientation > 8) return null;
  try {
    return _Rotator(b, segments, orientation).run();
  } on _Skip {
    return null;
  } on FormatException {
    return null;
  } on RangeError {
    return null;
  }
}

class _Skip implements Exception {
  const _Skip();
}

const _zigzag = <int>[
  0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, //
  12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28,
  35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
  58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63,
];

class _Comp {
  _Comp(this.id, this.h, this.v, this.tq);

  final int id;
  int h;
  int v;
  final int tq;
  int td = 0;
  int ta = 0;
  int gw = 0; // grid width in blocks (padded to whole MCUs)
  int gh = 0;
  Int16List coef = Int16List(0);
}

/// 16-bit look-ahead decoding table: entry = (code length << 8) | symbol.
class _HuffDec {
  _HuffDec(Uint8List b, int countsAt, int valsAt) : lut = Int32List(65536) {
    var code = 0;
    var k = 0;
    for (var len = 1; len <= 16; len++) {
      final n = b[countsAt + len - 1];
      for (var i = 0; i < n; i++) {
        if (code >= (1 << len)) throw const _Skip();
        final sym = b[valsAt + k++];
        final first = code << (16 - len);
        final count = 1 << (16 - len);
        final entry = (len << 8) | sym;
        for (var j = 0; j < count; j++) {
          lut[first + j] = entry;
        }
        code++;
      }
      code <<= 1;
    }
  }

  final Int32List lut;
}

class _Bits {
  _Bits(this.b, this.pos, this.end);

  final Uint8List b;
  int pos;
  final int end;
  int buf = 0;
  int cnt = 0;
  int synthetic = 0;
  bool atMarker = false;

  void fill() {
    while (cnt <= 24) {
      var byte = 0;
      if (atMarker || pos >= end) {
        synthetic++;
      } else {
        byte = b[pos];
        if (byte == 0xFF) {
          final next = pos + 1 < end ? b[pos + 1] : 0xD9;
          if (next == 0x00) {
            pos += 2;
          } else {
            atMarker = true;
            byte = 0;
            synthetic++;
          }
        } else {
          pos++;
        }
      }
      buf = ((buf << 8) | byte) & 0xFFFFFFFFFF;
      cnt += 8;
    }
  }

  int sym(Int32List lut) {
    fill();
    final e = lut[(buf >> (cnt - 16)) & 0xFFFF];
    if (e == 0) throw const _Skip();
    cnt -= e >> 8;
    return e & 0xFF;
  }

  int receive(int s) {
    if (s == 0) return 0;
    fill();
    cnt -= s;
    final v = (buf >> cnt) & ((1 << s) - 1);
    return v < (1 << (s - 1)) ? v - (1 << s) + 1 : v;
  }

  /// Consumes the RSTn marker that ends a restart interval.
  void restart() {
    buf = 0;
    cnt = 0;
    if (pos + 1 < end &&
        b[pos] == 0xFF &&
        b[pos + 1] >= 0xD0 &&
        b[pos + 1] <= 0xD7) {
      pos += 2;
      atMarker = false;
      synthetic = 0;
    } else {
      throw const _Skip();
    }
  }
}

class _Out {
  Uint8List buf = Uint8List(1 << 16);
  int len = 0;
  int acc = 0;
  int nb = 0;

  void _add(int v) {
    if (len == buf.length) {
      final bigger = Uint8List(buf.length * 2)..setRange(0, len, buf);
      buf = bigger;
    }
    buf[len++] = v;
  }

  void put(int code, int size) {
    acc = (acc << size) | (code & ((1 << size) - 1));
    nb += size;
    while (nb >= 8) {
      nb -= 8;
      final v = (acc >> nb) & 0xFF;
      _add(v);
      if (v == 0xFF) _add(0);
    }
    acc &= (1 << nb) - 1;
  }

  void finish() {
    if (nb > 0) put((1 << (8 - nb)) - 1, 8 - nb);
  }
}

class _HuffEnc {
  _HuffEnc(this.bits, this.vals) {
    var code = 0;
    var k = 0;
    for (var len = 1; len <= 16; len++) {
      for (var i = 0; i < bits[len]; i++) {
        final s = vals[k++];
        codes[s] = code++;
        sizes[s] = len;
      }
      code <<= 1;
    }
  }

  /// Optimal length-limited (16) table, JPEG Annex K.2 / K.3.
  factory _HuffEnc.optimal(Int32List counts) {
    final freq = Int32List(257)..setRange(0, 256, counts);
    freq[256] = 1; // reserved code point so no symbol gets the all-ones code
    final size = Int32List(257);
    final others = Int32List(257)..fillRange(0, 257, -1);
    for (;;) {
      var c1 = -1;
      var v = 1 << 30;
      for (var i = 0; i <= 256; i++) {
        if (freq[i] != 0 && freq[i] <= v) {
          v = freq[i];
          c1 = i;
        }
      }
      var c2 = -1;
      v = 1 << 30;
      for (var i = 0; i <= 256; i++) {
        if (freq[i] != 0 && freq[i] <= v && i != c1) {
          v = freq[i];
          c2 = i;
        }
      }
      if (c2 < 0) break;
      freq[c1] += freq[c2];
      freq[c2] = 0;
      size[c1]++;
      while (others[c1] >= 0) {
        c1 = others[c1];
        size[c1]++;
      }
      others[c1] = c2;
      size[c2]++;
      while (others[c2] >= 0) {
        c2 = others[c2];
        size[c2]++;
      }
    }
    final bits = List<int>.filled(33, 0);
    for (var i = 0; i <= 256; i++) {
      if (size[i] != 0) {
        if (size[i] > 32) throw const _Skip();
        bits[size[i]]++;
      }
    }
    for (var i = 32; i > 16; i--) {
      while (bits[i] > 0) {
        var j = i - 2;
        while (bits[j] == 0) {
          j--;
        }
        bits[i] -= 2;
        bits[i - 1]++;
        bits[j + 1] += 2;
        bits[j]--;
      }
    }
    var i = 16;
    while (bits[i] == 0) {
      i--;
    }
    bits[i]--; // drop the reserved code point
    final vals = <int>[];
    for (var len = 1; len <= 32; len++) {
      for (var j = 0; j < 256; j++) {
        if (size[j] == len) vals.add(j);
      }
    }
    return _HuffEnc(bits.sublist(0, 17), vals);
  }

  final List<int> bits; // index 1..16
  final List<int> vals;
  final codes = Int32List(256);
  final sizes = Int32List(256);

  Uint8List segment(int tcTh) {
    final n = 2 + 1 + 16 + vals.length;
    final o = Uint8List(n + 2);
    o[0] = 0xFF;
    o[1] = 0xC4;
    o[2] = n >> 8;
    o[3] = n & 0xFF;
    o[4] = tcTh;
    for (var i = 1; i <= 16; i++) {
      o[4 + i] = bits[i];
    }
    for (var i = 0; i < vals.length; i++) {
      o[21 + i] = vals[i];
    }
    return o;
  }
}

int _bitLength(int v) {
  var n = 0;
  while (v != 0) {
    n++;
    v >>= 1;
  }
  return n;
}

class _Rotator {
  _Rotator(this.b, this.segments, this.orientation);

  final Uint8List b;
  final List<JpegSegment> segments;
  final int orientation;

  Uint8List run() {
    // ---- locate the structural segments -------------------------------
    JpegSegment? sof;
    JpegSegment? sos;
    final dht = <JpegSegment>[];
    final dqt = <JpegSegment>[];
    var dri = 0;
    for (final s in segments) {
      final m = s.marker;
      if (m == 0xC0 || m == 0xC1) {
        if (sof != null) throw const _Skip();
        sof = s;
      } else if (m == 0xC4) {
        dht.add(s);
      } else if (m == 0xDB) {
        dqt.add(s);
      } else if (m == 0xDD) {
        dri = u16be(b, s.start + 4);
      } else if (m == 0xDA) {
        if (sos != null) throw const _Skip();
        sos = s;
      } else if ((m >= 0xC2 && m <= 0xCF) || m == 0xDC) {
        throw const _Skip(); // progressive, lossless, arithmetic, DNL
      }
    }
    if (sof == null || sos == null) throw const _Skip();
    for (final s in [...dht, ...dqt]) {
      if (s.start > sos.start) throw const _Skip();
    }

    // ---- SOF -----------------------------------------------------------
    final sp = sof.start + 4;
    final sofLen = u16be(b, sof.start + 2);
    if (b[sp] != 8) throw const _Skip();
    final height = u16be(b, sp + 1);
    final width = u16be(b, sp + 3);
    final nf = b[sp + 5];
    if (height == 0 || width == 0 || nf < 1 || nf > 4) throw const _Skip();
    if (sofLen != 8 + 3 * nf) throw const _Skip();
    final comps = <_Comp>[];
    for (var i = 0; i < nf; i++) {
      final q = sp + 6 + 3 * i;
      final h = b[q + 1] >> 4;
      final v = b[q + 1] & 15;
      if (h < 1 || h > 4 || v < 1 || v > 4) throw const _Skip();
      comps.add(_Comp(b[q], nf == 1 ? 1 : h, nf == 1 ? 1 : v, b[q + 2]));
    }

    // ---- DHT -----------------------------------------------------------
    final decDc = List<_HuffDec?>.filled(4, null);
    final decAc = List<_HuffDec?>.filled(4, null);
    for (final s in dht) {
      var p = s.start + 4;
      final end = s.start + 2 + u16be(b, s.start + 2);
      while (p < end) {
        final tc = b[p] >> 4;
        final th = b[p] & 15;
        if (tc > 1 || th > 3) throw const _Skip();
        var total = 0;
        for (var i = 1; i <= 16; i++) {
          total += b[p + i];
        }
        if (total > 256 || p + 17 + total > end) throw const _Skip();
        final t = _HuffDec(b, p + 1, p + 17);
        (tc == 0 ? decDc : decAc)[th] = t;
        p += 17 + total;
      }
    }

    // ---- SOS header ----------------------------------------------------
    final xp = sos.start + 4;
    final sosLen = u16be(b, sos.start + 2);
    final ns = b[xp];
    if (ns != nf || sosLen != 6 + 2 * ns) throw const _Skip();
    if (b[xp + 1 + 2 * ns] != 0 ||
        b[xp + 2 + 2 * ns] != 63 ||
        b[xp + 3 + 2 * ns] != 0) {
      throw const _Skip();
    }
    final scan = <_Comp>[];
    for (var i = 0; i < ns; i++) {
      final id = b[xp + 1 + 2 * i];
      final c = comps.firstWhere((c) => c.id == id,
          orElse: () => throw const _Skip());
      if (scan.contains(c)) throw const _Skip();
      c.td = b[xp + 2 + 2 * i] >> 4;
      c.ta = b[xp + 2 + 2 * i] & 15;
      if (c.td > 3 || c.ta > 3) throw const _Skip();
      scan.add(c);
    }
    final dataStart = sos.start + 2 + sosLen;

    // ---- geometry ------------------------------------------------------
    var hmax = 1;
    var vmax = 1;
    for (final c in comps) {
      if (c.h > hmax) hmax = c.h;
      if (c.v > vmax) vmax = c.v;
    }
    final mcusX = (width + 8 * hmax - 1) ~/ (8 * hmax);
    final mcusY = (height + 8 * vmax - 1) ~/ (8 * vmax);
    var blocks = 0;
    for (final c in comps) {
      c.gw = mcusX * c.h;
      c.gh = mcusY * c.v;
      blocks += c.gw * c.gh;
    }
    if (blocks > 40 * 1000 * 1000) throw const _Skip();

    final tr = orientation == 5 ||
        orientation == 6 ||
        orientation == 7 ||
        orientation == 8;
    final hf = orientation == 2 ||
        orientation == 3 ||
        orientation == 6 ||
        orientation == 7;
    final vf = orientation == 3 ||
        orientation == 4 ||
        orientation == 7 ||
        orientation == 8;
    final outW = tr ? height : width;
    final outH = tr ? width : height;
    final outHmax = tr ? vmax : hmax;
    final outVmax = tr ? hmax : vmax;
    // A mirror is only exact when no padding block would end up on the
    // leading edge, i.e. when the dimension is a whole number of MCUs.
    if (hf && outW % (8 * outHmax) != 0) throw const _Skip();
    if (vf && outH % (8 * outVmax) != 0) throw const _Skip();

    // ---- decode coefficients -------------------------------------------
    for (final c in comps) {
      c.coef = Int16List(c.gw * c.gh * 64);
    }
    final bits = _Bits(b, dataStart, sos.end);
    final pred = List<int>.filled(nf, 0);
    var mcu = 0;
    for (var my = 0; my < mcusY; my++) {
      for (var mx = 0; mx < mcusX; mx++) {
        if (dri > 0 && mcu > 0 && mcu % dri == 0) {
          bits.restart();
          pred.fillRange(0, nf, 0);
        }
        for (var ci = 0; ci < scan.length; ci++) {
          final c = scan[ci];
          final dc = decDc[c.td];
          final ac = decAc[c.ta];
          if (dc == null || ac == null) throw const _Skip();
          for (var r = 0; r < c.v; r++) {
            for (var k = 0; k < c.h; k++) {
              final off = ((my * c.v + r) * c.gw + mx * c.h + k) * 64;
              final s = bits.sym(dc.lut);
              if (s > 15) throw const _Skip();
              pred[ci] += bits.receive(s);
              c.coef[off] = pred[ci];
              var z = 1;
              while (z < 64) {
                final rs = bits.sym(ac.lut);
                final run = rs >> 4;
                final size = rs & 15;
                if (size == 0) {
                  if (run == 15) {
                    z += 16;
                    continue;
                  }
                  break;
                }
                z += run;
                if (z > 63) throw const _Skip();
                c.coef[off + _zigzag[z]] = bits.receive(size);
                z++;
              }
            }
          }
        }
        mcu++;
      }
    }
    // Reading past the data (truncated file) must not pass as a valid image.
    if (bits.synthetic * 8 > bits.cnt) throw const _Skip();

    // ---- transform ---------------------------------------------------------
    final outComps = <_Comp>[];
    for (final c in comps) {
      final oc = _Comp(c.id, tr ? c.v : c.h, tr ? c.h : c.v, c.tq)
        ..td = c.td
        ..ta = c.ta;
      oc.gw = tr ? c.gh : c.gw;
      oc.gh = tr ? c.gw : c.gh;
      final out = Int16List(c.coef.length);
      final src = c.coef;
      for (var by = 0; by < c.gh; by++) {
        for (var bx = 0; bx < c.gw; bx++) {
          var x = tr ? by : bx;
          var y = tr ? bx : by;
          if (hf) x = oc.gw - 1 - x;
          if (vf) y = oc.gh - 1 - y;
          final from = (by * c.gw + bx) * 64;
          final to = (y * oc.gw + x) * 64;
          for (var i = 0; i < 64; i++) {
            final row = i >> 3;
            final col = i & 7;
            var v = src[from + (tr ? col * 8 + row : i)];
            if (hf && (col & 1) == 1) v = -v;
            if (vf && (row & 1) == 1) v = -v;
            out[to + i] = v;
          }
        }
      }
      oc.coef = out;
      c.coef = Int16List(0);
      outComps.add(oc);
    }

    // ---- re-encode with optimised Huffman tables -----------------------
    final outScan = [for (final c in scan) outComps[comps.indexOf(c)]];
    final omx = (outW + 8 * outHmax - 1) ~/ (8 * outHmax);
    final omy = (outH + 8 * outVmax - 1) ~/ (8 * outVmax);

    final dcFreq = List.generate(4, (_) => Int32List(256));
    final acFreq = List.generate(4, (_) => Int32List(256));
    _encode(outScan, omx, omy, null, dcFreq, acFreq, null, null);
    final encDc = List<_HuffEnc?>.filled(4, null);
    final encAc = List<_HuffEnc?>.filled(4, null);
    for (var i = 0; i < 4; i++) {
      if (dcFreq[i].any((f) => f != 0)) encDc[i] = _HuffEnc.optimal(dcFreq[i]);
      if (acFreq[i].any((f) => f != 0)) encAc[i] = _HuffEnc.optimal(acFreq[i]);
    }
    final w = _Out();
    _encode(outScan, omx, omy, w, null, null, encDc, encAc);
    w.finish();

    // ---- assemble ------------------------------------------------------
    final body = BytesBuilder(copy: false);
    for (final s in dqt) {
      body.add(_dqtSegment(s, tr));
    }
    final sofOut =
        Uint8List.fromList(b.sublist(sof.start, sof.start + 2 + sofLen));
    final oy = tr ? width : height;
    final ox = tr ? height : width;
    sofOut[5] = oy >> 8;
    sofOut[6] = oy & 0xFF;
    sofOut[7] = ox >> 8;
    sofOut[8] = ox & 0xFF;
    for (var i = 0; i < nf; i++) {
      sofOut[10 + 3 * i + 1] = (outComps[i].h << 4) | outComps[i].v;
    }
    body.add(sofOut);
    for (var i = 0; i < 4; i++) {
      final t = encDc[i];
      if (t != null) body.add(t.segment(i));
    }
    for (var i = 0; i < 4; i++) {
      final t = encAc[i];
      if (t != null) body.add(t.segment(0x10 | i));
    }
    body.add(b.sublist(sos.start, dataStart));
    body.add(Uint8List.view(w.buf.buffer, 0, w.len));
    return body.takeBytes();
  }

  /// One pass over the output scan: counts symbols when [w] is null, writes
  /// them otherwise.
  void _encode(
    List<_Comp> scan,
    int mcusX,
    int mcusY,
    _Out? w,
    List<Int32List>? dcFreq,
    List<Int32List>? acFreq,
    List<_HuffEnc?>? encDc,
    List<_HuffEnc?>? encAc,
  ) {
    final pred = List<int>.filled(scan.length, 0);
    for (var my = 0; my < mcusY; my++) {
      for (var mx = 0; mx < mcusX; mx++) {
        for (var ci = 0; ci < scan.length; ci++) {
          final c = scan[ci];
          for (var r = 0; r < c.v; r++) {
            for (var k = 0; k < c.h; k++) {
              final off = ((my * c.v + r) * c.gw + mx * c.h + k) * 64;
              final co = c.coef;

              final diff = co[off] - pred[ci];
              pred[ci] = co[off];
              final a = diff < 0 ? -diff : diff;
              final s = _bitLength(a);
              if (s > 11) throw const _Skip();
              if (w == null) {
                dcFreq![c.td][s]++;
              } else {
                final t = encDc![c.td]!;
                w.put(t.codes[s], t.sizes[s]);
                if (s > 0) w.put(diff < 0 ? diff - 1 : diff, s);
              }

              var run = 0;
              for (var z = 1; z < 64; z++) {
                final v = co[off + _zigzag[z]];
                if (v == 0) {
                  run++;
                  continue;
                }
                while (run > 15) {
                  _acSymbol(w, acFreq, encAc, c.ta, 0xF0);
                  run -= 16;
                }
                final av = v < 0 ? -v : v;
                final size = _bitLength(av);
                if (size > 10) throw const _Skip();
                _acSymbol(w, acFreq, encAc, c.ta, (run << 4) | size);
                if (w != null) w.put(v < 0 ? v - 1 : v, size);
                run = 0;
              }
              if (run > 0) _acSymbol(w, acFreq, encAc, c.ta, 0x00);
            }
          }
        }
      }
    }
  }

  static void _acSymbol(
    _Out? w,
    List<Int32List>? freq,
    List<_HuffEnc?>? enc,
    int table,
    int sym,
  ) {
    if (w == null) {
      freq![table][sym]++;
    } else {
      final t = enc![table]!;
      w.put(t.codes[sym], t.sizes[sym]);
    }
  }

  /// Copies a DQT segment; for a transposed image every table is transposed
  /// too, because the coefficients it quantises moved to (v, u).
  Uint8List _dqtSegment(JpegSegment s, bool transpose) {
    final out = Uint8List.fromList(
        b.sublist(s.start, s.start + 2 + u16be(b, s.start + 2)));
    if (!transpose) return out;
    var p = 4;
    while (p < out.length) {
      final wide = (out[p] >> 4) != 0;
      final step = wide ? 2 : 1;
      if (p + 1 + 64 * step > out.length) throw const _Skip();
      final natural = List<int>.filled(64, 0);
      for (var k = 0; k < 64; k++) {
        final o = p + 1 + k * step;
        natural[_zigzag[k]] = wide ? (out[o] << 8) | out[o + 1] : out[o];
      }
      for (var k = 0; k < 64; k++) {
        final n = _zigzag[k];
        final v = natural[(n & 7) * 8 + (n >> 3)];
        final o = p + 1 + k * step;
        if (wide) {
          out[o] = v >> 8;
          out[o + 1] = v & 0xFF;
        } else {
          out[o] = v;
        }
      }
      p += 1 + 64 * step;
    }
    return out;
  }
}
