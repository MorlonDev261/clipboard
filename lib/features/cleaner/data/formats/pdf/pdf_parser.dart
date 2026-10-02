import 'dart:typed_data';

/// Minimal PDF object model: every value remembers its byte span in the buffer
/// it was parsed from, so a dictionary can be re-emitted with entries cut out
/// without re-serialising (and possibly altering) the rest.
sealed class PObj {
  PObj(this.start, this.end);

  final int start;
  final int end;
}

class PDict extends PObj {
  PDict(super.start, super.end, this.entries);

  final List<PEntry> entries;

  PObj? operator [](String key) {
    for (final e in entries) {
      if (e.key == key) return e.value;
    }
    return null;
  }
}

class PEntry {
  PEntry(this.key, this.keyStart, this.value);

  final String key;
  final int keyStart;
  final PObj value;
}

class PArray extends PObj {
  PArray(super.start, super.end, this.items);

  final List<PObj> items;
}

class PRef extends PObj {
  PRef(super.start, super.end, this.num, this.gen);

  final int num;
  final int gen;
}

class PName extends PObj {
  PName(super.start, super.end, this.name);

  final String name;
}

class PNum extends PObj {
  PNum(super.start, super.end, this.value);

  final num value;
}

/// String, boolean or null: opaque to us.
class PAtom extends PObj {
  PAtom(super.start, super.end);
}

/// Recursive-descent parser over a byte buffer.
class PdfParser {
  PdfParser(this.b);

  final Uint8List b;

  static bool isSpace(int c) =>
      c == 0 || c == 9 || c == 10 || c == 12 || c == 13 || c == 32;

  static bool isDelim(int c) =>
      c == 0x28 ||
      c == 0x29 ||
      c == 0x3C ||
      c == 0x3E ||
      c == 0x5B ||
      c == 0x5D ||
      c == 0x7B ||
      c == 0x7D ||
      c == 0x2F ||
      c == 0x25;

  static bool isRegular(int c) => !isSpace(c) && !isDelim(c);

  int skipSpace(int p) {
    while (p < b.length) {
      final c = b[p];
      if (isSpace(c)) {
        p++;
      } else if (c == 0x25) {
        while (p < b.length && b[p] != 10 && b[p] != 13) {
          p++;
        }
      } else {
        break;
      }
    }
    return p;
  }

  bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  /// Parses an `N G R` reference at [p] if there is one.
  PRef? _tryRef(int p) {
    var q = p;
    var n = 0;
    final s = q;
    while (q < b.length && _isDigit(b[q]) && q - s < 10) {
      n = n * 10 + b[q] - 0x30;
      q++;
    }
    if (q == s || q >= b.length || !isSpace(b[q])) return null;
    q = skipSpace(q);
    final g0 = q;
    var g = 0;
    while (q < b.length && _isDigit(b[q]) && q - g0 < 6) {
      g = g * 10 + b[q] - 0x30;
      q++;
    }
    if (q == g0 || q >= b.length || !isSpace(b[q])) return null;
    q = skipSpace(q);
    if (q < b.length &&
        b[q] == 0x52 &&
        (q + 1 >= b.length || !isRegular(b[q + 1]))) {
      return PRef(p, q + 1, n, g);
    }
    return null;
  }

  PObj parse(int pos, [int depth = 0]) {
    if (depth > 64) throw const FormatException('PDF nesting too deep');
    final p = skipSpace(pos);
    if (p >= b.length) throw const FormatException('Unexpected end of PDF');
    final c = b[p];
    if (c == 0x3C && p + 1 < b.length && b[p + 1] == 0x3C) {
      return _dict(p, depth);
    }
    if (c == 0x5B) return _array(p, depth);
    if (c == 0x2F) return _name(p);
    if (c == 0x28) return _literalString(p);
    if (c == 0x3C) {
      var q = p + 1;
      while (q < b.length && b[q] != 0x3E) {
        q++;
      }
      return PAtom(p, q + 1);
    }
    if (_isDigit(c)) {
      final ref = _tryRef(p);
      if (ref != null) return ref;
    }
    var q = p;
    while (q < b.length && isRegular(b[q])) {
      q++;
    }
    if (q == p) throw FormatException('Unexpected byte ${b[p]} in PDF object');
    final token = String.fromCharCodes(b.sublist(p, q));
    final v = num.tryParse(token);
    if (v != null) return PNum(p, q, v);
    return PAtom(p, q); // true / false / null / keyword
  }

  PName _name(int p) {
    var q = p + 1;
    while (q < b.length && isRegular(b[q])) {
      q++;
    }
    // Decode #xx escapes so /M#65tadata cannot hide from key matching.
    final out = <int>[];
    for (var i = p + 1; i < q; i++) {
      if (b[i] == 0x23 &&
          i + 2 < q &&
          _hex(b[i + 1]) >= 0 &&
          _hex(b[i + 2]) >= 0) {
        out.add(_hex(b[i + 1]) * 16 + _hex(b[i + 2]));
        i += 2;
      } else {
        out.add(b[i]);
      }
    }
    return PName(p, q, String.fromCharCodes(out));
  }

  static int _hex(int c) {
    if (c >= 0x30 && c <= 0x39) return c - 0x30;
    if (c >= 0x41 && c <= 0x46) return c - 0x41 + 10;
    if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10;
    return -1;
  }

  PAtom _literalString(int p) {
    var q = p + 1;
    var depth = 1;
    while (q < b.length && depth > 0) {
      final c = b[q];
      if (c == 0x5C) {
        q++; // skip the escaped byte
      } else if (c == 0x28) {
        depth++;
      } else if (c == 0x29) {
        depth--;
      }
      q++;
    }
    if (depth != 0) throw const FormatException('Unterminated PDF string');
    return PAtom(p, q);
  }

  PArray _array(int p, int depth) {
    final items = <PObj>[];
    var q = p + 1;
    while (true) {
      q = skipSpace(q);
      if (q >= b.length) throw const FormatException('Unterminated array');
      if (b[q] == 0x5D) return PArray(p, q + 1, items);
      final v = parse(q, depth + 1);
      items.add(v);
      q = v.end;
    }
  }

  PDict _dict(int p, int depth) {
    final entries = <PEntry>[];
    var q = p + 2;
    while (true) {
      q = skipSpace(q);
      if (q + 1 >= b.length) throw const FormatException('Unterminated dict');
      if (b[q] == 0x3E && b[q + 1] == 0x3E) return PDict(p, q + 2, entries);
      if (b[q] != 0x2F) throw const FormatException('Dict key is not a name');
      final key = _name(q);
      final v = parse(key.end, depth + 1);
      entries.add(PEntry(key.name, q, v));
      q = v.end;
    }
  }
}
