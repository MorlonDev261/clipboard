import 'dart:convert';
import 'dart:typed_data';

int u16be(Uint8List b, int o) => (b[o] << 8) | b[o + 1];

int u32be(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

int u32le(Uint8List b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

int u64be(Uint8List b, int o) {
  var v = 0;
  for (var i = 0; i < 8; i++) {
    v = v * 256 + b[o + i];
  }
  return v;
}

Uint8List be16(int v) => Uint8List(2)
  ..[0] = (v >> 8) & 0xFF
  ..[1] = v & 0xFF;

Uint8List be32(int v) => Uint8List(4)
  ..[0] = (v >> 24) & 0xFF
  ..[1] = (v >> 16) & 0xFF
  ..[2] = (v >> 8) & 0xFF
  ..[3] = v & 0xFF;

Uint8List le32(int v) => Uint8List(4)
  ..[0] = v & 0xFF
  ..[1] = (v >> 8) & 0xFF
  ..[2] = (v >> 16) & 0xFF
  ..[3] = (v >> 24) & 0xFF;

void putU32be(Uint8List b, int o, int v) {
  b[o] = (v >> 24) & 0xFF;
  b[o + 1] = (v >> 16) & 0xFF;
  b[o + 2] = (v >> 8) & 0xFF;
  b[o + 3] = v & 0xFF;
}

void putU64be(Uint8List b, int o, int v) {
  for (var i = 7; i >= 0; i--) {
    b[o + i] = v & 0xFF;
    v = v ~/ 256;
  }
}

Uint8List ascii4(String s) => Uint8List.fromList(ascii.encode(s));

/// Four ASCII characters at [o]; non-printable bytes become `?` (never throws).
String fourcc(Uint8List b, int o) =>
    String.fromCharCodes([for (var i = 0; i < 4; i++) _printable(b[o + i])]);

int _printable(int c) => c >= 0x20 && c < 0x7F ? c : 0x3F;

bool startsWithAscii(Uint8List b, int offset, String prefix) {
  if (offset < 0 || offset + prefix.length > b.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (b[offset + i] != prefix.codeUnitAt(i)) return false;
  }
  return true;
}

/// Index of [needle] in [haystack] at or after [from], or -1.
int indexOfBytes(Uint8List haystack, List<int> needle, [int from = 0]) {
  final first = needle.first;
  final last = haystack.length - needle.length;
  for (var i = from; i <= last; i++) {
    if (haystack[i] != first) continue;
    var j = 1;
    while (j < needle.length && haystack[i + j] == needle[j]) {
      j++;
    }
    if (j == needle.length) return i;
  }
  return -1;
}

final _crcTable = () {
  final t = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    t[n] = c;
  }
  return t;
}();

int crc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// `1.2 KB`-style size for report rows.
String sizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Printable, single-line, length-capped text for a report value.
String clipText(String s, [int max = 160]) {
  final t = s.replaceAll(RegExp(r'[\x00-\x08\x0B-\x1F\x7F]'), '').trim();
  return t.length > max ? '${t.substring(0, max)}…' : t;
}

String latin1Text(Uint8List b, int start, int end) =>
    clipText(latin1.decode(b.sublist(start, end), allowInvalid: true));

String utf8Text(Uint8List b, int start, int end) =>
    clipText(utf8.decode(b.sublist(start, end), allowMalformed: true));
