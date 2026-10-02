import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clipboard/features/cleaner/data/binary.dart';

Uint8List bytes(Iterable<int> v) => Uint8List.fromList(v.toList());

Uint8List cat(Iterable<List<int>> parts) {
  final b = BytesBuilder(copy: false);
  for (final p in parts) {
    b.add(p);
  }
  return b.takeBytes();
}

List<int> asc(String s) => latin1.encode(s);

/// Big-endian TIFF with Make, Orientation, an Exif IFD (DateTimeOriginal), a
/// GPS IFD and a chained IFD1 (thumbnail) — everything a phone photo carries.
Uint8List tiffWithEverything({int orientation = 6}) {
  final b = BytesBuilder(copy: false);
  Uint8List entry(int tag, int type, int count, int value) {
    final e = Uint8List(12);
    e[0] = tag >> 8;
    e[1] = tag & 0xFF;
    e[3] = type;
    putU32be(e, 4, count);
    if (type == 3 && count == 1) {
      e[8] = value >> 8;
      e[9] = value & 0xFF;
    } else {
      putU32be(e, 8, value);
    }
    return e;
  }

  // Layout: header(8) | IFD0 (2+4*12+4=54) | ExifIFD (2+12+4=18) | GPS (18)
  const ifd0 = 8;
  const exifIfd = ifd0 + 54;
  const gpsIfd = exifIfd + 18;
  const ifd1 = gpsIfd + 18;
  b.add([0x4D, 0x4D, 0x00, 0x2A]);
  b.add(be32(ifd0));
  b.add(be16(4));
  b.add(entry(0x010F, 2, 4, 0)); // Make
  b.add(entry(0x0112, 3, 1, orientation));
  b.add(entry(0x8769, 4, 1, exifIfd));
  b.add(entry(0x8825, 4, 1, gpsIfd));
  b.add(be32(ifd1)); // next IFD → thumbnail
  b.add(be16(1));
  b.add(entry(0x9003, 2, 20, 0)); // DateTimeOriginal
  b.add(be32(0));
  b.add(be16(1));
  b.add(entry(0x0001, 2, 2, 0)); // GPSLatitudeRef
  b.add(be32(0));
  b.add(be16(0)); // empty IFD1
  b.add(be32(0));
  return b.takeBytes();
}

// -- JPEG ---------------------------------------------------------------

Uint8List jpegSegment(int marker, List<int> payload) => cat([
      bytes([0xFF, marker]),
      be16(payload.length + 2),
      payload
    ]);

/// Entropy-coded data with byte stuffing and an RST marker, to prove the
/// parser does not mistake them for segment boundaries.
final jpegScan = bytes([0x12, 0xFF, 0x00, 0x34, 0xFF, 0xD0, 0x56, 0xFF, 0x00]);

Uint8List jpegWithMetadata({int orientation = 6}) => cat([
      [0xFF, 0xD8],
      jpegSegment(
          0xE0, [...asc('JFIF\u0000'), 1, 1, 0, 0, 1, 0, 1, 1, 1, 9, 9, 9]),
      jpegSegment(0xE1, [
        ...asc('Exif\u0000\u0000'),
        ...tiffWithEverything(orientation: orientation)
      ]),
      jpegSegment(0xE1, [
        ...asc('http://ns.adobe.com/xap/1.0/\u0000'),
        ...asc('<x:xmpmeta/>')
      ]),
      jpegSegment(0xE2, [...asc('ICC_PROFILE\u0000'), 1, 1, 7, 7]),
      jpegSegment(0xED, [...asc('Photoshop 3.0\u0000'), ...asc('8BIM')]),
      jpegSegment(0xFE, asc('shot by someone')),
      jpegSegment(0xDB, [0, 1, 2, 3]),
      jpegSegment(0xC0, [8, 0, 1, 0, 1, 1, 1, 0x11, 0]),
      jpegSegment(0xDA, [1, 1, 0, 0, 0x3F, 0]),
      jpegScan,
      [0xFF, 0xD9],
      asc('TRAILER-WITH-MPF-IMAGE'),
    ]);

// -- PNG ----------------------------------------------------------------

Uint8List pngChunk(String type, List<int> data) {
  final td = cat([asc(type), data]);
  return cat([be32(data.length), td, be32(crc32(td))]);
}

final pngIdat = [0x78, 0x9C, 0x63, 0x60, 0x00, 0x00];

Uint8List pngWithMetadata() => cat([
      [137, 80, 78, 71, 13, 10, 26, 10],
      pngChunk('IHDR', [0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0]),
      pngChunk('sRGB', [0]),
      pngChunk('tEXt', [...asc('parameters'), 0, ...asc('a secret prompt')]),
      pngChunk('tIME', [7, 0xE8, 1, 2, 3, 4, 5]),
      pngChunk('eXIf', tiffWithEverything()),
      pngChunk(
          'iTXt', [...asc('XML:com.adobe.xmp'), 0, 0, 0, 0, 0, ...asc('<x/>')]),
      pngChunk('caBX', [1, 2, 3]),
      pngChunk('IDAT', pngIdat),
      pngChunk('IEND', []),
      asc('PAYLOAD-AFTER-IEND'),
    ]);

// -- WebP ---------------------------------------------------------------

Uint8List riffChunk(String type, List<int> data) => cat([
      asc(type),
      le32(data.length),
      data,
      if (data.length.isOdd) [0],
    ]);

Uint8List webpWithMetadata() {
  final body = cat([
    asc('WEBP'),
    riffChunk('VP8X', [0x08 | 0x04 | 0x20, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
    riffChunk('ICCP', [1, 2, 3, 4]),
    riffChunk('VP8 ', [1, 2, 3, 4, 5]), // odd size → padding byte
    riffChunk('EXIF', tiffWithEverything()),
    riffChunk('XMP ', asc('<x:xmpmeta/>')),
  ]);
  return cat([asc('RIFF'), le32(body.length), body]);
}

// -- GIF ----------------------------------------------------------------

/// Image data deliberately contains `21 FE` (a comment-extension introducer)
/// inside an LZW sub-block, which a naive byte scan would corrupt.
Uint8List gifWithMetadata() => cat([
      asc('GIF89a'),
      [1, 0, 1, 0, 0x80, 0, 0], // 1x1, global colour table of 2 entries
      [0, 0, 0, 255, 255, 255],
      [0x21, 0xFF, 11, ...asc('NETSCAPE2.0'), 3, 1, 0, 0, 0],
      [0x21, 0xFF, 11, ...asc('XMP DataXMP'), 4, 1, 2, 3, 4, 0],
      [0x21, 0xFE, 5, ...asc('hello'), 0],
      [0x21, 0xF9, 4, 0, 0, 0, 0, 0],
      [0x2C, 0, 0, 0, 0, 1, 0, 1, 0, 0],
      [2, 4, 0x21, 0xFE, 0x05, 0x01, 0],
      [0x3B],
      asc('JUNK'),
    ]);

// -- MP4 ----------------------------------------------------------------

Uint8List isoBox(String type, List<int> payload) =>
    cat([be32(payload.length + 8), asc(type), payload]);

/// One H.264 access unit: a user-data SEI (x264-style encoder string) followed
/// by an IDR slice, both with 4-byte length prefixes.
final seiNal = () {
  final text = asc('x264 - core 164 secret-settings');
  final payload = [...List.filled(16, 7), ...text];
  return bytes([0x06, 0x05, payload.length, ...payload, 0x80]);
}();
final idrNal = bytes([0x65, 1, 2, 3, 4, 5, 6, 7, 8]);
final videoSample =
    cat([be32(seiNal.length), seiNal, be32(idrNal.length), idrNal]);
const gpsSampleText = 'GPS-SAMPLE-SECRET-48.85N';

Uint8List _hdlr(String type, String name) => isoBox('hdlr', [
      0, 0, 0, 0, 0, 0, 0, 0, ...asc(type), ...List.filled(12, 0), //
      ...asc(name), 0,
    ]);

Uint8List _stbl({
  required List<int> stsd,
  required int sampleSize,
  required int chunkOffset,
}) =>
    isoBox('stbl', [
      ...isoBox('stsd', stsd),
      ...isoBox('stsz', [0, 0, 0, 0, ...be32(sampleSize), ...be32(1)]),
      ...isoBox(
          'stsc', [0, 0, 0, 0, ...be32(1), ...be32(1), ...be32(1), ...be32(1)]),
      ...isoBox('stco', [0, 0, 0, 0, ...be32(1), ...be32(chunkOffset)]),
    ]);

Uint8List _avc1() {
  final entry = [
    ...List.filled(6, 0), 0, 1, ...List.filled(16, 0), 0, 64, 0, 64,
    0, 0x48, 0, 0, 0, 0x48, 0, 0, 0, 0, 0, 0, 0, 1, //
    ...[...asc('x264 coding'), ...List.filled(21, 0)], // 32-byte compressorname
    0, 24, 0xFF, 0xFF,
    ...isoBox('avcC', [1, 100, 0, 30, 0xFF, 0xE0, 0]),
  ];
  return cat([
    [0, 0, 0, 0],
    be32(1),
    isoBox('avc1', entry),
  ]);
}

Uint8List _trak(String handler, String name, List<int> stbl) => isoBox('trak', [
      ...isoBox('tkhd', [
        0,
        0,
        0,
        3,
        ...be32(0xAAAAAAAA),
        ...be32(0xBBBBBBBB),
        ...List.filled(72, 0)
      ]),
      ...isoBox('mdia', [
        ...isoBox('mdhd', [
          0,
          0,
          0,
          0,
          ...be32(0xAAAAAAAA),
          ...be32(0xBBBBBBBB),
          ...List.filled(12, 0)
        ]),
        ..._hdlr(handler, name),
        ...isoBox('minf', [
          ...isoBox('vmhd', [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0]),
          ...stbl,
        ]),
      ]),
      ...isoBox('udta', asc('\u00A9xyz+48.8566+002.3522/')),
    ]);

/// MP4 with GPS/make/model in `udta` + `meta`, timestamps, vendor handler names,
/// an H.264 track (compressor name + x264 SEI) and optionally a timed GPS
/// metadata track whose samples live in `mdat`.
///
/// Layout of mdat payload: [videoSample][gps sample]. The video track's `stco`
/// points at the video sample, the metadata track's at the GPS sample.
Uint8List mp4WithMetadata({
  bool moovFirst = true,
  bool timedMetaTrack = false,
  bool withFtyp = true,
}) {
  final gps = asc(gpsSampleText);
  Uint8List moovFor(int mdatPayloadAt) => isoBox('moov', [
        ...isoBox('mvhd', [
          0,
          0,
          0,
          0,
          ...be32(0xAAAAAAAA),
          ...be32(0xBBBBBBBB),
          ...List.filled(80, 0)
        ]),
        ..._trak(
            'vide',
            'Core Media Video',
            _stbl(
                stsd: _avc1(),
                sampleSize: videoSample.length,
                chunkOffset: mdatPayloadAt)),
        if (timedMetaTrack)
          ..._trak(
              'meta',
              'GPS Track',
              _stbl(
                  stsd: [0, 0, 0, 0, ...be32(0)],
                  sampleSize: gps.length,
                  chunkOffset: mdatPayloadAt + videoSample.length)),
        ...isoBox('udta', [...asc('\u00A9mod'), ...asc('iPhone 15 Pro')]),
        ...isoBox('meta',
            [0, 0, 0, 0, ...asc('mdta com.apple.quicktime.location.ISO6709')]),
      ]);

  // Classic QuickTime movies may begin with a `wide` box instead of `ftyp`.
  final ftyp = withFtyp
      ? isoBox('ftyp', [...asc('isom'), 0, 0, 2, 0, ...asc('isom')])
      : isoBox('wide', []);
  final free = isoBox('free', List.filled(64, 0));
  final mdat = isoBox('mdat', [...videoSample, ...gps]);
  final moovLen = moovFor(0).length;
  if (moovFirst) {
    return cat(
        [ftyp, moovFor(ftyp.length + moovLen + free.length + 8), free, mdat]);
  }
  return cat([ftyp, mdat, moovFor(ftyp.length + 8), free]);
}

// -- HEIC ---------------------------------------------------------------

final heicImage = bytes(List.generate(40, (i) => 0xA0 + (i % 16)));

/// Item payload of an Exif item: 4-byte TIFF offset (6 = after "Exif\0\0").
final heicExifItem = cat([
  be32(6),
  asc('Exif'),
  [0, 0],
  tiffWithEverything()
]);

Uint8List heicWithMetadata() {
  Uint8List metaFor(int imageAt, int exifAt) {
    Uint8List infe(int id, String type) =>
        isoBox('infe', [2, 0, 0, 0, ...be16(id), 0, 0, ...asc(type), 0]);
    Uint8List ilocItem(int id, int off, int len) =>
        cat([be16(id), be16(0), be16(1), be32(off), be32(len)]);
    return isoBox('meta', [
      0,
      0,
      0,
      0,
      ..._hdlr('pict', ''),
      ...isoBox('pitm', [0, 0, 0, 0, 0, 1]),
      ...isoBox(
          'iinf', [0, 0, 0, 0, 0, 2, ...infe(1, 'hvc1'), ...infe(2, 'Exif')]),
      ...isoBox('iloc', [
        0,
        0,
        0,
        0,
        0x44,
        0x00,
        0,
        2,
        ...ilocItem(1, imageAt, heicImage.length),
        ...ilocItem(2, exifAt, heicExifItem.length),
      ]),
      ...isoBox('iref', [
        0,
        0,
        0,
        0,
        ...isoBox('cdsc', [...be16(2), ...be16(1), ...be16(1)])
      ]),
      ...isoBox('iprp', [
        ...isoBox('ipco', []),
        ...isoBox(
            'ipma', [0, 0, 0, 0, ...be32(2), ...be16(1), 1, 1, ...be16(2), 0]),
      ]),
    ]);
  }

  final ftyp = isoBox(
      'ftyp', [...asc('heic'), 0, 0, 0, 0, ...asc('mif1'), ...asc('heic')]);
  final len = metaFor(0, 0).length;
  final imageAt = ftyp.length + len + 8;
  final exifAt = imageAt + heicImage.length;
  return cat([
    ftyp,
    metaFor(imageAt, exifAt),
    isoBox('mdat', [...heicImage, ...heicExifItem]),
  ]);
}

// -- Matroska / WebM -----------------------------------------------------

Uint8List ebml(int id, List<int> payload, {int sizeBytes = 0}) {
  final idBytes = <int>[];
  var v = id;
  while (v > 0) {
    idBytes.insert(0, v & 0xFF);
    v >>= 8;
  }
  var n = payload.length;
  var s = sizeBytes;
  if (s == 0) {
    s = 1;
    while (n >= (1 << (7 * s)) - 1) {
      s++;
    }
  }
  final size = List<int>.filled(s, 0);
  for (var i = s - 1; i >= 0; i--) {
    size[i] = n & 0xFF;
    n >>= 8;
  }
  size[0] |= 0x80 >> (s - 1);
  return cat([idBytes, size, payload]);
}

const mkvBlockText = 'FRAME-BYTES-0123';

Uint8List mkvWithMetadata() {
  final info = ebml(0x1549A966, [
    ...ebml(0xBF, [1, 2, 3, 4]), // CRC-32
    ...ebml(0x2AD7B1, [0x0F, 0x42, 0x40]),
    ...ebml(0x4D80, asc('libwebm-0.2.1.0')),
    ...ebml(0x5741, asc('Lavf58.76 secret-tool')),
    ...ebml(0x4461, [1, 2, 3, 4, 5, 6, 7, 8]),
    ...ebml(0x7BA9, asc('My private title')),
  ]);
  final tracks = ebml(0x1654AE6B, [
    ...ebml(0xAE, [
      ...ebml(0xD7, [1]),
      ...ebml(0x536E, asc('Camera of John')),
      ...ebml(0x86, asc('V_VP9')),
    ]),
  ]);
  final tags = ebml(0x1254C367, [
    ...ebml(0x7373, [
      ...ebml(0x67C8, [
        ...ebml(0x45A3, asc('ENCODER')),
        ...ebml(0x4487, asc('secret encoder'))
      ])
    ]),
  ]);
  final cluster = ebml(0x1F43B675, [
    ...ebml(0xE7, [0]),
    ...ebml(0xA3, [0x81, 0, 0, 0x80, ...asc(mkvBlockText)]),
  ]);
  final segment = ebml(0x18538067, [
    ...ebml(0x114D9B74, [
      ...ebml(0xEC, [0, 0, 0])
    ]),
    ...info,
    ...tracks,
    ...cluster,
    ...tags, // at the end, after the clusters
  ]);
  return cat([
    ebml(0x1A45DFA3, [...ebml(0x4282, asc('webm'))]),
    segment,
  ]);
}

// -- PDF -------------------------------------------------------------------

Uint8List pdfObj(int n, String body, {List<int>? stream, int gen = 0}) => cat([
      asc('$n $gen obj\n$body'),
      if (stream != null) ...[asc('\nstream\n'), stream, asc('\nendstream')],
      asc('\nendobj\n'),
    ]);

const pdfPageText = 'BT /F1 12 Tf (Hello visible content) Tj ET';

/// Classic PDF with Info (author/producer/dates), XMP, PieceInfo, a thumbnail,
/// an annotation with author + date, an embedded JPEG carrying EXIF, an orphan
/// object left by an old edit, and an incremental update that replaced Info.
Uint8List pdfWithMetadata({bool objStm = false}) {
  final jpeg = jpegWithMetadata(orientation: 1);
  final page = '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] '
      '/Contents 5 0 R /Annots [6 0 R] /Thumb 9 0 R '
      '/Resources << /XObject << /Im 10 0 R >> >> >>';
  final info = '<< /Title (Secret title) /Author (John Doe) '
      '/Producer (Word secret-producer) /CreationDate (D:20250102030405) >>';
  final parts = <List<int>>[
    asc('%PDF-1.5\n%\u00E2\u00E3\u00CF\u00D3\n'),
    pdfObj(
        1,
        '<< /Type /Catalog /Pages 2 0 R /Metadata 4 0 R '
        '/PieceInfo << /App << /Private (secret-piece) >> >> >>'),
    pdfObj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
  ];
  if (objStm) {
    // Page (3) and Info (7) live in a compressed object stream.
    final b3 = page;
    final b7 = info;
    final header = '3 0 7 ${b3.length + 1} ';
    final raw = asc('$header$b3 $b7');
    final z = ZLibEncoder().convert(raw);
    parts.add(pdfObj(11,
        '<< /Type /ObjStm /N 2 /First ${header.length} /Filter /FlateDecode /Length ${z.length} >>',
        stream: z));
  } else {
    parts.add(pdfObj(3, page));
  }
  parts.addAll([
    pdfObj(4, '<< /Type /Metadata /Subtype /XML /Length 31 >>',
        stream: asc('<x:xmpmeta>secret-xmp</x:xmpmeta>')),
    pdfObj(5, '<< /Length ${pdfPageText.length} >>', stream: asc(pdfPageText)),
    pdfObj(
        6,
        '<< /Type /Annot /Subtype /Text /Rect [0 0 5 5] /T (Jane Reviewer) '
        '/M (D:20250202020202) /Contents (a note) >>'),
    if (!objStm) pdfObj(7, info),
    pdfObj(8, '<< /Old (deleted secret text) >>'),
    pdfObj(
        9, '<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /Length 3 >>',
        stream: [1, 2, 3]),
    pdfObj(
        10,
        '<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray '
        '/BitsPerComponent 8 /Filter /DCTDecode /Length ${jpeg.length} >>',
        stream: jpeg),
    asc('xref\n0 1\n0000000000 65535 f \n'),
    asc('trailer\n<< /Size 12 /Root 1 0 R /Info 7 0 R /ID [<AA><BB>] >>\nstartxref\n0\n%%EOF\n'),
    // Incremental update: Info replaced by a new revision.
    pdfObj(7, '<< /Author (New Author) >>'),
    asc('trailer\n<< /Size 12 /Root 1 0 R /Info 7 0 R /Prev 0 >>\nstartxref\n0\n%%EOF\n'),
  ]);
  return cat(parts);
}

// -- TIFF ------------------------------------------------------------------

const tiffPixels = 'PIXELDATA-0123456';

/// Little-endian TIFF: dimensions, strip, orientation + Make (out-of-line),
/// Software (inline), Exif IFD (DateTimeOriginal) and GPS IFD.
Uint8List tiffWithMetadata({bool dng = false}) {
  Uint8List le16(int v) => bytes([v & 0xFF, v >> 8]);
  Uint8List e(int tag, int type, int count, int value) =>
      cat([le16(tag), le16(type), le32(count), le32(value)]);
  final entries = [
    e(256, 3, 1, 2),
    e(257, 3, 1, 2),
    e(271, 2, 17, 122),
    e(273, 4, 1, 139),
    e(274, 3, 1, 6),
    e(279, 4, 1, 17),
    e(305, 2, 3, 0x006261),
    e(34665, 4, 1, 156),
    e(34853, 4, 1, 174),
    if (dng) e(50706, 1, 4, 0x00000401),
  ];
  entries.sort((a, b) => (a[0] | a[1] << 8).compareTo(b[0] | b[1] << 8));
  final ifd0 = cat([le16(entries.length), ...entries, le32(0)]);
  // Offsets above assume 9 entries (114-byte IFD0 → data from 122).
  assert(dng || ifd0.length == 114);
  final exifIfd = cat([le16(1), e(0x9003, 2, 20, 192), le32(0)]);
  final gpsIfd = cat([le16(1), e(1, 2, 2, 0x4E), le32(0)]);
  return cat([
    asc('II'),
    le16(42),
    le32(8),
    ifd0,
    List.filled(dng ? 0 : 122 - 8 - ifd0.length, 0),
    [...asc('Canon EOS secret'), 0],
    asc(tiffPixels),
    exifIfd,
    gpsIfd,
    [...asc('2025:01:02 03:04:05'), 0],
  ]);
}

/// Two-page TIFF (IFD0 -> IFD1), each page with only structural tags.
Uint8List tiffMultiPage() {
  Uint8List le16(int v) => bytes([v & 0xFF, v >> 8]);
  Uint8List e(int tag, int type, int count, int value) =>
      cat([le16(tag), le16(type), le32(count), le32(value)]);
  Uint8List ifd(int next) => cat([
        le16(3),
        e(256, 3, 1, 2),
        e(257, 3, 1, 2),
        e(305, 2, 3, 0x006261),
        le32(next),
      ]);
  final first = ifd(8 + 2 + 36 + 4);
  return cat([asc('II'), le16(42), le32(8), first, ifd(0)]);
}
