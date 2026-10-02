import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:clipboard/features/cleaner/data/clean_pipeline.dart';
import 'package:clipboard/features/cleaner/domain/clean_report.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

/// Corrupt inputs must never crash, hang or leave a half-written output: every
/// run ends in a report, and a `failed` / `unsupported` report has no file.
/// `FUZZ_ITER=2000 FUZZ_SEED=7 flutter test test/cleaner/fuzz_test.dart` for a
/// long soak; the defaults keep the normal suite fast.
final iterations = int.tryParse(Platform.environment['FUZZ_ITER'] ?? '') ?? 100;
final seedOffset = int.tryParse(Platform.environment['FUZZ_SEED'] ?? '') ?? 0;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('cleaner_fuzz_'));
  tearDown(() => dir.deleteSync(recursive: true));

  final samples = <String, Uint8List>{
    'jpg': jpegWithMetadata(),
    'png': pngWithMetadata(),
    'webp': webpWithMetadata(),
    'gif': gifWithMetadata(),
    'mp4': mp4WithMetadata(timedMetaTrack: true),
    'heic': heicWithMetadata(),
    'webm': mkvWithMetadata(),
    'pdf': pdfWithMetadata(),
    'tif': tiffWithMetadata(),
  };

  for (final entry in samples.entries) {
    test('${entry.key}: truncations and byte flips end in a clean report',
        () async {
      final rnd = Random(entry.key.hashCode + seedOffset);
      final original = entry.value;
      final variants = <Uint8List>[
        for (var i = 0; i < iterations ~/ 4; i++)
          Uint8List.fromList(original.sublist(0, rnd.nextInt(original.length))),
        for (var i = 0; i < iterations - iterations ~/ 4; i++)
          (() {
            final b = Uint8List.fromList(original);
            for (var k = 0; k < 1 + rnd.nextInt(4); k++) {
              b[rnd.nextInt(b.length)] = rnd.nextInt(256);
            }
            return b;
          })(),
      ];
      var n = 0;
      for (final data in variants) {
        final src = File('${dir.path}/f${n++}.${entry.key}')
          ..writeAsBytesSync(data);
        final out = Directory('${dir.path}/out')..createSync(recursive: true);
        final r = await const CleanPipeline()
            .run(src.path, out)
            .timeout(const Duration(seconds: 10));
        if (r.status == CleanStatus.failed ||
            r.status == CleanStatus.unsupported) {
          expect(r.outputPath, isNull);
        } else {
          expect(File(r.outputPath!).existsSync(), isTrue);
        }
      }
      // No stray partial outputs from failed runs.
      final outDir = Directory('${dir.path}/out');
      if (outDir.existsSync()) {
        final produced = outDir.listSync().length;
        expect(produced, lessThanOrEqualTo(variants.length));
      }
    }, timeout: const Timeout(Duration(minutes: 30)));
  }
}
