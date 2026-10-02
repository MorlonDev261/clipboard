import 'dart:io';
import 'dart:typed_data';

import 'package:clipboard/features/cleaner/data/binary.dart';
import 'package:clipboard/features/cleaner/data/clean_pipeline.dart';
import 'package:clipboard/features/cleaner/data/exif_inspector.dart';
import 'package:clipboard/features/cleaner/domain/clean_options.dart';
import 'package:clipboard/features/cleaner/domain/clean_report.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('cleaner_test_'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<CleanReport> run(String name, Uint8List data,
      [CleanOptions options = const CleanOptions()]) async {
    final src = File('${dir.path}/$name')..writeAsBytesSync(data);
    final out = Directory('${dir.path}/out')..createSync(recursive: true);
    return const CleanPipeline().run(src.path, out, options);
  }

  Set<MetadataCategory> categories(List<MetadataFinding> f) =>
      f.map((e) => e.category).toSet();

  bool has(Uint8List hay, String needle) => indexOfBytes(hay, asc(needle)) >= 0;

  group('JPEG', () {
    test('strips everything identifying and verifies the output', () async {
      final r = await run('a.jpg', jpegWithMetadata());
      expect(r.status, CleanStatus.verifiedClean);
      expect(
        categories(r.removed),
        containsAll([
          MetadataCategory.gps,
          MetadataCategory.device,
          MetadataCategory.dateTime,
          MetadataCategory.thumbnail,
          MetadataCategory.xmp,
          MetadataCategory.iptc,
          MetadataCategory.comment,
          MetadataCategory.trailingData,
        ]),
      );
      expect(r.remaining, isEmpty);

      final out = File(r.outputPath!).readAsBytesSync();
      for (final s in [
        'http://ns.adobe.com',
        'Photoshop',
        'shot by',
        'TRAILER'
      ]) {
        expect(has(out, s), isFalse, reason: s);
      }
    });

    test('keeps the entropy-coded data byte for byte', () async {
      final r = await run('a.jpg', jpegWithMetadata());
      final out = File(r.outputPath!).readAsBytesSync();
      expect(indexOfBytes(out, [...jpegScan, 0xFF, 0xD9]), greaterThan(0));
      expect(out.sublist(out.length - 2), [0xFF, 0xD9]);
      expect(out.sublist(0, 2), [0xFF, 0xD8]);
    });

    test('preserves orientation through a minimal, harmless EXIF block',
        () async {
      final r = await run('a.jpg', jpegWithMetadata(orientation: 6));
      final out = File(r.outputPath!).readAsBytesSync();
      final at = indexOfBytes(out, [...asc('Exif'), 0, 0]);
      expect(at, greaterThan(0));
      final info = ExifInspector.inspect(out, at + 6, out.length);
      expect(info.orientation, 6);
      expect(info.findings.where((f) => f.sensitive), isEmpty);
      expect(r.after.where((f) => f.sensitive), isEmpty);
    });

    test('can drop orientation and ICC profile on request', () async {
      final r = await run(
        'a.jpg',
        jpegWithMetadata(),
        const CleanOptions(preserveOrientation: false, keepColorProfile: false),
      );
      final out = File(r.outputPath!).readAsBytesSync();
      expect(has(out, 'Exif'), isFalse);
      expect(has(out, 'ICC_PROFILE'), isFalse);
    });

    test('is idempotent', () async {
      final first = await run('a.jpg', jpegWithMetadata());
      final bytes = File(first.outputPath!).readAsBytesSync();
      final second = await run('b.jpg', bytes);
      expect(second.removed, isEmpty);
      expect(File(second.outputPath!).readAsBytesSync(), bytes);
    });

    test('rejects a corrupt file without leaving an output', () async {
      final r = await run(
          'bad.jpg', bytes([0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x50, 1, 2]));
      expect(r.status, CleanStatus.failed);
      expect(r.outputPath, isNull);
      expect(Directory('${dir.path}/out').listSync(), isEmpty);
    });
  });

  group('PNG', () {
    test('removes text, tIME, eXIf, XMP, C2PA and trailing data', () async {
      final r = await run('a.png', pngWithMetadata());
      expect(r.status, CleanStatus.verifiedClean);
      expect(
        categories(r.removed),
        containsAll([
          MetadataCategory.comment,
          MetadataCategory.dateTime,
          MetadataCategory.gps,
          MetadataCategory.xmp,
          MetadataCategory.provenance,
          MetadataCategory.trailingData,
        ]),
      );
      // The text keyword is surfaced so users see e.g. AI-prompt leaks.
      expect(r.removed.any((f) => f.label.contains('parameters')), isTrue);

      final out = File(r.outputPath!).readAsBytesSync();
      expect(has(out, 'secret prompt'), isFalse);
      expect(has(out, 'PAYLOAD'), isFalse);
      expect(has(out, 'IDAT'), isTrue);
      expect(has(out, 'sRGB'), isTrue);
    });

    test('writes a CRC-valid minimal eXIf before IDAT', () async {
      final r = await run('a.png', pngWithMetadata());
      final out = File(r.outputPath!).readAsBytesSync();
      final at = indexOfBytes(out, asc('eXIf')) - 4;
      expect(at, greaterThan(0));
      final len = u32be(out, at);
      expect(
          u32be(out, at + 8 + len), crc32(out.sublist(at + 4, at + 8 + len)));
      expect(at, lessThan(indexOfBytes(out, asc('IDAT'))));
    });
  });

  group('WebP', () {
    test('drops EXIF/XMP and fixes the VP8X flags', () async {
      final r = await run('a.webp', webpWithMetadata());
      expect(r.status, CleanStatus.verifiedClean);
      final out = File(r.outputPath!).readAsBytesSync();
      expect(has(out, 'XMP '), isFalse);
      // RIFF size must match the real length.
      expect(u32le(out, 4) + 8, out.length);
      final vp8x = indexOfBytes(out, asc('VP8X'));
      final flags = out[vp8x + 8];
      expect(flags & 0x04, 0, reason: 'XMP flag cleared');
      expect(flags & 0x20, 0x20, reason: 'ICC kept');
      expect(flags & 0x08, 0x08, reason: 'minimal EXIF carries orientation');
      // Odd-sized VP8 chunk keeps its padding.
      expect(has(out, 'VP8 '), isTrue);
    });
  });

  group('GIF', () {
    test('drops comments/XMP, keeps loop + image data untouched', () async {
      final r = await run('a.gif', gifWithMetadata());
      expect(r.status, CleanStatus.verifiedClean);
      expect(categories(r.removed),
          containsAll([MetadataCategory.comment, MetadataCategory.xmp]));
      final out = File(r.outputPath!).readAsBytesSync();
      expect(has(out, 'NETSCAPE2.0'), isTrue);
      expect(has(out, 'hello'), isFalse);
      expect(has(out, 'JUNK'), isFalse);
      // The LZW sub-block that merely *looks* like a comment survived.
      expect(
          indexOfBytes(out, [2, 4, 0x21, 0xFE, 0x05, 0x01, 0]), greaterThan(0));
      expect(out.last, 0x3B);
    });
  });

  group('MP4 / MOV', () {
    /// Chunk offset of the n-th `stco` (0 = video track, 1 = metadata track).
    int chunkOffset(Uint8List out, [int n = 0]) {
      var at = -1;
      for (var i = 0; i <= n; i++) {
        at = indexOfBytes(out, asc('stco'), at + 1);
      }
      return u32be(out, at + 12);
    }

    for (final moovFirst in [true, false]) {
      test(
          'remaps chunk offsets when moov ${moovFirst ? "precedes" : "follows"} mdat',
          () async {
        final r = await run('v.mp4', mp4WithMetadata(moovFirst: moovFirst));
        expect(r.status, CleanStatus.verifiedClean);
        final out = File(r.outputPath!).readAsBytesSync();
        final off = chunkOffset(out);
        // The IDR slice after the (neutralised) SEI is untouched and still
        // where stco says the sample lives.
        final idrAt = off + 4 + seiNal.length + 4;
        expect(out.sublist(idrAt, idrAt + idrNal.length), idrNal);
        expect(
            out.length, lessThan(mp4WithMetadata(moovFirst: moovFirst).length));
      });
    }

    test('removes location, device, timestamps, handler and codec names',
        () async {
      final r = await run('v.mp4', mp4WithMetadata());
      expect(
        categories(r.removed),
        containsAll([
          MetadataCategory.gps,
          MetadataCategory.device,
          MetadataCategory.dateTime,
        ]),
      );
      final out = File(r.outputPath!).readAsBytesSync();
      for (final s in [
        'xyz',
        'iPhone',
        'ISO6709',
        'Core Media',
        'x264 coding'
      ]) {
        expect(has(out, s), isFalse, reason: s);
      }
      expect(has(out, 'free'), isFalse);
      expect(r.remaining, isEmpty);
      expect(r.caveats, isEmpty);
    });

    test('neutralises x264 SEI as same-length filler, nothing else changes',
        () async {
      final r = await run('v.mp4', mp4WithMetadata());
      expect(r.removed.any((f) => f.label.contains('SEI')), isTrue);
      final out = File(r.outputPath!).readAsBytesSync();
      expect(has(out, 'x264 - core'), isFalse);
      final off = chunkOffset(out);
      expect(u32be(out, off), seiNal.length);
      expect(out[off + 4] & 0x1F, 12, reason: 'filler data NAL');
      expect(out[off + 4 + seiNal.length - 1], 0x80);
    });

    test('handles QuickTime files that start with `wide`, not `ftyp`',
        () async {
      final r = await run('q.mov', mp4WithMetadata(withFtyp: false));
      expect(r.format, MediaFormat.isoVideo);
      expect(r.status, CleanStatus.verifiedClean, reason: '${r.errorMessage}');
      final out = File(r.outputPath!).readAsBytesSync();
      final idrAt = chunkOffset(out) + 4 + seiNal.length + 4;
      expect(out.sublist(idrAt, idrAt + idrNal.length), idrNal);
    });

    test('blanks the bytes of a dropped timed-metadata track', () async {
      final r = await run('v.mp4', mp4WithMetadata(timedMetaTrack: true));
      expect(r.status, CleanStatus.verifiedClean);
      expect(categories(r.removed), contains(MetadataCategory.timedTrack));
      final out = File(r.outputPath!).readAsBytesSync();
      expect(has(out, 'GPS Track'), isFalse);
      expect(has(out, 'GPS-SAMPLE'), isFalse, reason: 'payload zeroed in mdat');
      // Video data right before it is intact.
      final idrAt = chunkOffset(out) + 4 + seiNal.length + 4;
      expect(out.sublist(idrAt, idrAt + idrNal.length), idrNal);
    });

    test('is idempotent', () async {
      final first = await run('v.mp4', mp4WithMetadata());
      final bytes = File(first.outputPath!).readAsBytesSync();
      final second = await run('w.mp4', bytes);
      expect(second.removed, isEmpty);
      expect(File(second.outputPath!).readAsBytesSync(), bytes);
    });
  });

  group('HEIC / AVIF', () {
    test('removes the Exif item, remaps iloc and blanks its bytes', () async {
      final r = await run('p.heic', heicWithMetadata());
      expect(r.format, MediaFormat.heif);
      expect(r.status, CleanStatus.verifiedClean);
      // The Exif item is inspected: the report says what it held.
      expect(categories(r.removed), contains(MetadataCategory.exif));
      expect(r.removed.first.label, contains('gps'));

      final out = File(r.outputPath!).readAsBytesSync();
      expect(has(out, 'Exif'), isFalse);
      // iloc entry of item 1 (the image): ver/flags(4) sizes(2) count(2) → id,
      // dri, extent_count, offset, length.
      final iloc = indexOfBytes(out, asc('iloc')) + 4;
      final offset = u32be(out, iloc + 8 + 2 + 2 + 2);
      expect(out.sublist(offset, offset + heicImage.length), heicImage);
      expect(u16be(out, iloc + 6), 1, reason: 'one item left');
      // pitm, hvc1 item and the cdsc reference to the removed item are gone.
      expect(has(out, 'cdsc'), isFalse);
    });

    test('is idempotent', () async {
      final first = await run('p.heic', heicWithMetadata());
      final bytes = File(first.outputPath!).readAsBytesSync();
      final second = await run('q.heic', bytes);
      expect(second.removed, isEmpty);
      expect(File(second.outputPath!).readAsBytesSync(), bytes);
    });
  });

  group('Matroska / WebM', () {
    test('voids tags, app names, dates, titles, track names in place',
        () async {
      final src = mkvWithMetadata();
      final r = await run('v.webm', src);
      expect(r.format, MediaFormat.matroska);
      expect(r.status, CleanStatus.verifiedClean);
      expect(
        categories(r.removed),
        containsAll([
          MetadataCategory.container,
          MetadataCategory.device,
          MetadataCategory.dateTime,
          MetadataCategory.comment,
        ]),
      );
      final out = File(r.outputPath!).readAsBytesSync();
      expect(out.length, src.length, reason: 'no offset may shift');
      for (final s in [
        'libwebm',
        'secret-tool',
        'private title',
        'Camera of John',
        'secret encoder',
        'ENCODER'
      ]) {
        expect(has(out, s), isFalse, reason: s);
      }
      // Codec id and the frame data are untouched.
      expect(has(out, 'V_VP9'), isTrue);
      expect(has(out, mkvBlockText), isTrue);
      expect(r.remaining, isEmpty);
    });

    test('is idempotent', () async {
      final first = await run('v.webm', mkvWithMetadata());
      final bytes = File(first.outputPath!).readAsBytesSync();
      final second = await run('w.webm', bytes);
      expect(second.removed, isEmpty);
      expect(File(second.outputPath!).readAsBytesSync(), bytes);
    });
  });

  group('PDF', () {
    for (final objStm in [false, true]) {
      test(
          'rebuilds without Info, XMP, annotations authors, old revisions'
          '${objStm ? " (object stream)" : ""}', () async {
        final r = await run('d.pdf', pdfWithMetadata(objStm: objStm));
        expect(r.format, MediaFormat.pdf);
        expect(r.status, CleanStatus.verifiedClean,
            reason: '${r.errorMessage} ${r.after}');
        expect(
          categories(r.removed),
          containsAll([
            MetadataCategory.comment,
            MetadataCategory.device,
            MetadataCategory.dateTime,
            MetadataCategory.xmp,
            MetadataCategory.trailingData,
            MetadataCategory.container,
            MetadataCategory.thumbnail,
            MetadataCategory.gps, // from the embedded JPEG's EXIF
          ]),
        );
        final out = File(r.outputPath!).readAsBytesSync();
        for (final s in [
          'Secret title',
          'John Doe',
          'New Author',
          'secret-producer',
          'secret-xmp',
          'secret-piece',
          'Jane Reviewer',
          'deleted secret',
          '/Info',
          '/Metadata',
          '/ID',
          'Photoshop',
          'http://ns.adobe.com',
        ]) {
          expect(has(out, s), isFalse, reason: s);
        }
        // Visible content, structure and the image survive.
        expect(has(out, pdfPageText), isTrue);
        expect(has(out, '/Type /Catalog'), isTrue);
        expect(has(out, 'a note'), isTrue);
        expect(has(out, '%%EOF'), isTrue);
      });
    }

    test('xref offsets point at their objects', () async {
      final r = await run('d.pdf', pdfWithMetadata());
      final out = File(r.outputPath!).readAsBytesSync();
      final text = String.fromCharCodes(out);
      final xref = text.lastIndexOf('xref\n0 ');
      final start =
          int.parse(RegExp(r'startxref\n(\d+)').firstMatch(text)!.group(1)!);
      expect(start, xref);
      final entries =
          RegExp(r'(\d{10}) (\d{5}) n ').allMatches(text.substring(xref));
      expect(entries, isNotEmpty);
      var n = 0;
      for (final m in entries) {
        n++;
        final off = int.parse(m.group(1)!);
        // Objects are numbered from 1; free entries are skipped by the regex.
        expect(text.substring(off).startsWith(RegExp(r'\d+ 0 obj')), isTrue,
            reason: 'entry $n');
      }
    });

    test('encrypted PDFs are refused, not mangled', () async {
      final src = cat([
        asc('%PDF-1.6\n'),
        pdfObj(1, '<< /Type /Catalog >>'),
        asc('trailer\n<< /Root 1 0 R /Encrypt 9 0 R >>\n'),
      ]);
      final r = await run('e.pdf', src);
      expect(r.status, CleanStatus.unsupported);
      expect(r.outputPath, isNull);
    });

    test('is idempotent', () async {
      final first = await run('d.pdf', pdfWithMetadata());
      final bytes = File(first.outputPath!).readAsBytesSync();
      final second = await run('e.pdf', bytes);
      expect(second.removed, isEmpty);
    });
  });

  group('TIFF', () {
    test('keeps pixel tags and orientation, zeroes everything else in place',
        () async {
      final src = tiffWithMetadata();
      final r = await run('t.tif', src);
      expect(r.format, MediaFormat.tiff);
      expect(r.status, CleanStatus.verifiedClean);
      expect(
        categories(r.removed),
        containsAll([
          MetadataCategory.device,
          MetadataCategory.dateTime,
          MetadataCategory.gps,
        ]),
      );
      final out = File(r.outputPath!).readAsBytesSync();
      expect(out.length, src.length, reason: 'nothing may move');
      for (final s in ['Canon', '2025:01', 'secret']) {
        expect(has(out, s), isFalse, reason: s);
      }
      expect(has(out, tiffPixels), isTrue);
      // IFD0 now lists 5 entries and still starts at offset 8.
      expect(out[8] | out[9] << 8, 5);
      expect(r.after.where((f) => f.sensitive), isEmpty);
      expect(r.after.map((f) => f.category),
          isNot(contains(MetadataCategory.gps)));
    });

    test('a second page is a page, not an Exif thumbnail', () async {
      final r = await run('m.tif', tiffMultiPage());
      expect(r.status, CleanStatus.verifiedClean, reason: '${r.after}');
      expect(r.remaining, isEmpty);
    });

    test('RAW / DNG is refused as unsupported, not damaged', () async {
      final r = await run('r.dng', tiffWithMetadata(dng: true));
      expect(r.status, CleanStatus.unsupported);
      expect(r.outputPath, isNull);
      expect(r.errorMessage, contains('RAW'));
    });

    test('is idempotent', () async {
      final first = await run('t.tif', tiffWithMetadata());
      final bytes = File(first.outputPath!).readAsBytesSync();
      final second = await run('u.tif', bytes);
      expect(second.removed, isEmpty);
      expect(File(second.outputPath!).readAsBytesSync(), bytes);
    });
  });

  group('detection and unsupported inputs', () {
    test('sniffs magic bytes, not the extension', () async {
      final r = await run('photo.jpg', pngWithMetadata());
      expect(r.format, MediaFormat.png);
      expect(r.outputPath, endsWith('.png'));
    });

    test('unknown formats are reported, not touched', () async {
      final r = await run('notes.bin', bytes([1, 2, 3, 4, 5]));
      expect(r.status, CleanStatus.unsupported);
      expect(r.outputPath, isNull);
    });
  });
}
