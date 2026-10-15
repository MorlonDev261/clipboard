import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:influencor/features/cleaner/data/clean_pipeline.dart';
import 'package:influencor/features/cleaner/domain/clean_options.dart';
import 'package:influencor/features/cleaner/domain/clean_report.dart';

// Real Pillow-made JPEGs (4:2:0, Make = "Acme", EXIF orientation 6).
const _aligned32x16 =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/4QAzRXhpZgAASUkqAAgAAAACAA8BAgAFAAAAJgAAABIBAwABAAAABgAAAAAAAABBY21lAP/bAEMACgcHCAcGCggICAsKCgsOGBAODQ0OHRUWERgjHyUkIh8iISYrNy8mKTQpISIwQTE0OTs+Pj4lLkRJQzxINz0+O//bAEMBCgsLDg0OHBAQHDsoIig7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7O//AABEIABAAIAMBIgACEQEDEQH/xAAfAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgv/xAC1EAACAQMDAgQDBQUEBAAAAX0BAgMABBEFEiExQQYTUWEHInEUMoGRoQgjQrHBFVLR8CQzYnKCCQoWFxgZGiUmJygpKjQ1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4eLj5OXm5+jp6vHy8/T19vf4+fr/xAAfAQADAQEBAQEBAQEBAAAAAAAAAQIDBAUGBwgJCgv/xAC1EQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJIzNS8BVictEKFiQ04SXxFxgZGiYnKCkqNTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqCg4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2dri4+Tl5ufo6ery8/T19vf4+fr/2gAMAwEAAhEDEQA/APONM8Y6hZ2/2O7Vb+zOf3Ux+Zc9Sr9Qc4PORwOK7vSfGGnarZXFu93L50lvsxMoEkjgHGcdTwct3AXO0j5uBsPCl7cJ514y2EHTdMPmPXov1HfHXjNdjoegWOmuZ1siViR2MszZkyOAOMY5JB247ZJIdQToJLmm7fn/AF93qKdZyg0tf679X0W/YNc1+x01xA16SsSIoihXMmRyTzjHJBG7HfAJCMOOv/Fd7cJ5Nmq2EHXbCfmPTq31HbHXnNd9q3g/TtVsre4S0l86S335hYCSRwBnGep4GF7gNjaR83Can4O1Czt/tloy39mcfvYR8y56Bk6g5yOMjg80QrpLlgrfn/X3egQouUE3r/Xbq+r37n//2Q==';
const _odd35x19 =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/4QAzRXhpZgAASUkqAAgAAAACAA8BAgAFAAAAJgAAABIBAwABAAAABgAAAAAAAABBY21lAP/bAEMACgcHCAcGCggICAsKCgsOGBAODQ0OHRUWERgjHyUkIh8iISYrNy8mKTQpISIwQTE0OTs+Pj4lLkRJQzxINz0+O//bAEMBCgsLDg0OHBAQHDsoIig7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7O//AABEIABMAIwMBIgACEQEDEQH/xAAfAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgv/xAC1EAACAQMDAgQDBQUEBAAAAX0BAgMABBEFEiExQQYTUWEHInEUMoGRoQgjQrHBFVLR8CQzYnKCCQoWFxgZGiUmJygpKjQ1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4eLj5OXm5+jp6vHy8/T19vf4+fr/xAAfAQADAQEBAQEBAQEBAAAAAAAAAQIDBAUGBwgJCgv/xAC1EQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJIzNS8BVictEKFiQ04SXxFxgZGiYnKCkqNTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqCg4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2dri4+Tl5ufo6ery8/T19vf4+fr/2gAMAwEAAhEDEQA/AOD0nx3eWwEGpx/bYcBS/SQDjv8AxYwTzg553Cuzh1vS/EGmhYLovOFwUIxKAQNwIwTzkdOCwAz3PlFnZXV/cCC0geaQ/wAKDOOcZPoORya7Pw34G3ul/e3yosDqxS3kwynAZcN3Pbg++7ik5e8pdUYOEIv3dOtl+f8AwTrYLiCyt2vbua2QA5jEjkDDMzKJP7uGZgeOoA61yOreO42Zvs6C+mIwZplKx4OCRsz83cc4+6vXFaN/4Wt/ECr9muJwI1HkNuZxsAUH5G6YxjqCxye2K4zV/DOqaKWa5g3wr/y2iO5O3U9RycDIGe2ac480m311+/X9dfknsipNStGb36bf16dmRT+IdZuZmmk1O53t12SFR+QwKKzqKSSRajFaJHr0FrBYXMVlaRLBbiOByiDG4tJsbcerZXjnP51p6sfJ0tBF8ga2ac7eMyHq315NFFctPWin19//ANtX6v733McD8DflH/0lmcXMesSuuN32kLkgHgzyKevsSPxrRulEd7IUG0tCzkjuwcAH8j+PeiivQxelaPov0JqJOMk/5JfhFtfczMl8HeH7mQzSaagZsZEbsi9PRSAKKKK9WFODim0jnpzlyLXof//Z';

({int w, int h}) _sofSize(Uint8List b) {
  for (var i = 0; i + 9 < b.length; i++) {
    if (b[i] == 0xFF && (b[i + 1] == 0xC0 || b[i + 1] == 0xC1)) {
      return (w: (b[i + 7] << 8) | b[i + 8], h: (b[i + 5] << 8) | b[i + 6]);
    }
  }
  throw StateError('no SOF');
}

bool _has(Uint8List b, String s) {
  final p = s.codeUnits;
  for (var i = 0; i + p.length <= b.length; i++) {
    var ok = true;
    for (var j = 0; j < p.length && ok; j++) {
      ok = b[i + j] == p[j];
    }
    if (ok) return true;
  }
  return false;
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('rot'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<CleanReport> clean(String b64) async {
    final src = File('${dir.path}/a.jpg')..writeAsBytesSync(base64Decode(b64));
    final out = Directory('${dir.path}/out')..createSync();
    return const CleanPipeline().run(src.path, out, CleanOptions.stripAll);
  }

  group('JPEG orientation baked into the pixels', () {
    test('rotates the coefficients and leaves no EXIF at all', () async {
      final r = await clean(_aligned32x16);
      final out = File(r.outputPath!).readAsBytesSync();
      expect(r.status, CleanStatus.verifiedClean);
      expect(r.caveats, isEmpty);
      expect(_sofSize(out), (w: 16, h: 32));
      expect(_has(out, 'Exif'), isFalse);
      expect(_has(out, 'Acme'), isFalse);
    });

    test('truncated and bit-flipped files never crash or hang', () async {
      final good = base64Decode(_aligned32x16);
      final out = Directory('${dir.path}/fz')..createSync();
      var i = 0;
      Future<void> run(Uint8List data) async {
        final f = File('${dir.path}/f${i++}.jpg')..writeAsBytesSync(data);
        final r =
            await const CleanPipeline().run(f.path, out, CleanOptions.stripAll);
        expect(r.status, isNot(CleanStatus.residualFound));
      }

      for (var n = 4; n < good.length; n += 7) {
        await run(Uint8List.fromList(good.sublist(0, n)));
      }
      for (var p = 150; p < good.length; p += 5) {
        final bad = Uint8List.fromList(good)..[p] ^= 0xA5;
        await run(bad);
      }
    });

    test('falls back to the minimal flag when edges are not MCU-aligned',
        () async {
      final r = await clean(_odd35x19);
      final out = File(r.outputPath!).readAsBytesSync();
      expect(r.status, CleanStatus.cleanedWithCaveats);
      expect(r.caveats, contains(CleanCaveat.orientationFlagKept));
      expect(_sofSize(out), (w: 35, h: 19));
      expect(_has(out, 'Exif'), isTrue);
      expect(_has(out, 'Acme'), isFalse);
    });
  });
}
