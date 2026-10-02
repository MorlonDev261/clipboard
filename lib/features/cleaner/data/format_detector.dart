import 'dart:io';
import 'dart:typed_data';

import '../domain/clean_report.dart';
import 'binary.dart';

/// Identifies a file by its magic bytes — a `.jpg` that is really a PNG, or a
/// file with no extension, is handled correctly.
class FormatDetector {
  const FormatDetector._();

  static const _heifBrands = {
    'heic', 'heix', 'heim', 'heis', 'hevc', 'hevx', 'mif1', 'msf1', 'avif',
    'avis', //
  };

  static Future<MediaFormat> detect(File file) async {
    final raf = await file.open();
    try {
      return detectBytes(await raf.read(16));
    } finally {
      await raf.close();
    }
  }

  static MediaFormat detectBytes(Uint8List h) {
    if (h.length >= 3 && h[0] == 0xFF && h[1] == 0xD8 && h[2] == 0xFF) {
      return MediaFormat.jpeg;
    }
    if (h.length >= 8 &&
        h[0] == 0x89 &&
        startsWithAscii(h, 1, 'PNG\r\n') &&
        h[6] == 0x1A) {
      return MediaFormat.png;
    }
    if (startsWithAscii(h, 0, 'GIF8')) return MediaFormat.gif;
    if (startsWithAscii(h, 0, '%PDF-')) return MediaFormat.pdf;
    if (h.length >= 4 &&
        ((h[0] == 0x49 &&
                h[1] == 0x49 &&
                (h[2] == 42 || h[2] == 43) &&
                h[3] == 0) ||
            (h[0] == 0x4D &&
                h[1] == 0x4D &&
                h[2] == 0 &&
                (h[3] == 42 || h[3] == 43)))) {
      return MediaFormat.tiff;
    }
    if (h.length >= 4 &&
        h[0] == 0x1A &&
        h[1] == 0x45 &&
        h[2] == 0xDF &&
        h[3] == 0xA3) {
      return MediaFormat.matroska;
    }
    if (h.length >= 12 && startsWithAscii(h, 0, 'RIFF')) {
      if (startsWithAscii(h, 8, 'WEBP')) return MediaFormat.webp;
      if (startsWithAscii(h, 8, 'AVI ')) return MediaFormat.avi;
    }
    // Classic QuickTime .mov files may start with `wide` / `mdat` / `moov`
    // instead of `ftyp` (the box layout is the same).
    if (h.length >= 8 &&
        const {'wide', 'mdat', 'moov', 'free', 'skip', 'pnot'}
            .contains(fourcc(h, 4)) &&
        u32be(h, 0) >= 8) {
      return MediaFormat.isoVideo;
    }
    if (h.length >= 12 && startsWithAscii(h, 4, 'ftyp')) {
      return _heifBrands.contains(fourcc(h, 8))
          ? MediaFormat.heif
          : MediaFormat.isoVideo;
    }
    return MediaFormat.unknown;
  }
}
