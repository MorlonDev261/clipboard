import 'dart:io';

import 'package:clipboard/features/cleaner/data/stale_copies.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('stale_'));
  tearDown(() => dir.deleteSync(recursive: true));

  String name(String base, DateTime t, String ext) =>
      '${base}_clean_${t.microsecondsSinceEpoch}$ext';

  test('removes old cleaned copies, keeps recent ones and everything else',
      () async {
    final now = DateTime.now();
    final old = File(p.join(
        dir.path, name('beach', now.subtract(const Duration(days: 3)), '.jpg')))
      ..writeAsBytesSync([1]);
    final recent = File(p.join(dir.path,
        name('fresh', now.subtract(const Duration(hours: 2)), '.mp4')))
      ..writeAsBytesSync([1]);
    final other = File(p.join(dir.path, 'report_clean.pdf'))
      ..writeAsBytesSync([1]);
    final unrelated = File(p.join(dir.path, 'x_clean_123.jpg'))
      ..writeAsBytesSync([1]);
    final inSub = Directory(p.join(dir.path, 'sub'))..createSync();
    final nested = File(p.join(inSub.path,
        name('deep', now.subtract(const Duration(days: 9)), '.png')))
      ..writeAsBytesSync([1]);

    final removed = await purgeStaleCleanCopies(dir, now: now);

    expect(removed, 1);
    expect(old.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue);
    expect(other.existsSync(), isTrue, reason: 'no timestamp → not ours');
    expect(unrelated.existsSync(), isTrue, reason: 'timestamp too short');
    expect(nested.existsSync(), isTrue, reason: 'only the temp folder itself');
  });

  test('a missing folder is not an error', () async {
    expect(await purgeStaleCleanCopies(Directory(p.join(dir.path, 'nope'))), 0);
  });

  test('the threshold is configurable', () async {
    final now = DateTime.now();
    final f = File(p.join(
        dir.path, name('a', now.subtract(const Duration(minutes: 30)), '.gif')))
      ..writeAsBytesSync([1]);
    expect(await purgeStaleCleanCopies(dir, now: now), 0);
    expect(
        await purgeStaleCleanCopies(dir,
            now: now, olderThan: const Duration(minutes: 10)),
        1);
    expect(f.existsSync(), isFalse);
  });
}
