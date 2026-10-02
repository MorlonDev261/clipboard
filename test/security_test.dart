import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clipboard/features/cleaner/data/binary.dart';
import 'package:clipboard/features/cleaner/data/clean_pipeline.dart';
import 'package:clipboard/features/cleaner/domain/clean_report.dart';
import 'package:clipboard/features/library/data/library_repository.dart';
import 'package:clipboard/features/library/data/metadata_store.dart';
import 'package:clipboard/features/library/data/trash_store.dart';
import 'package:clipboard/features/reseller/data/reseller_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'cleaner/fixtures.dart';

void main() {
  late Directory ws;
  late Directory outside;
  late LibraryRepository repo;

  setUp(() async {
    ws = await Directory.systemTemp.createTemp('sec_ws_');
    outside = await Directory.systemTemp.createTemp('sec_out_');
    repo = LibraryRepository(
      root: ws.path,
      metadata: MetadataStore(ws.path),
      trash: TrashStore(ws.path),
    );
  });

  tearDown(() async {
    for (final d in [ws, outside]) {
      if (await d.exists()) await d.delete(recursive: true);
    }
  });

  group('folders can never be moved or imported into themselves', () {
    test('"move" import of a folder into its own sub-folder loses nothing',
        () async {
      final a = Directory(p.join(ws.path, 'A'))..createSync();
      File(p.join(a.path, 'important.md')).writeAsStringSync('precious');
      final sub = Directory(p.join(a.path, 'sub'))..createSync();

      final failed = await repo.importPaths(sub.path, [a.path], move: true);

      expect(failed, [a.path]);
      expect(
          File(p.join(a.path, 'important.md')).readAsStringSync(), 'precious');
    });

    test('plain import into a sub-folder is refused too (no nested copy)',
        () async {
      final a = Directory(p.join(ws.path, 'A'))..createSync();
      File(p.join(a.path, 'n.md')).writeAsStringSync('x');
      final sub = Directory(p.join(a.path, 'sub'))..createSync();

      final failed = await repo.importPaths(sub.path, [a.path]);

      expect(failed, [a.path]);
      expect(sub.listSync(), isEmpty);
    });

    test('move() rejects a destination inside the source', () async {
      final a = Directory(p.join(ws.path, 'A'))..createSync();
      final sub = Directory(p.join(a.path, 'sub'))..createSync();
      await expectLater(
          repo.move(a.path, sub.path), throwsA(isA<FileSystemException>()));
      expect(a.existsSync(), isTrue);
    });

    test('a similarly named sibling is NOT "inside" (A vs A2)', () async {
      final a = Directory(p.join(ws.path, 'A'))..createSync();
      File(p.join(a.path, 'n.md')).writeAsStringSync('x');
      final a2 = Directory(p.join(ws.path, 'A2'))..createSync();
      final failed = await repo.importPaths(a2.path, [a.path]);
      expect(failed, isEmpty);
      expect(File(p.join(a2.path, 'A', 'n.md')).existsSync(), isTrue);
    });
  });

  group('trash index is untrusted input', () {
    Future<void> writeIndex(List<Map<String, Object?>> entries) async {
      final f = File(p.join(ws.path, '.clipboard', 'trash.json'))
        ..createSync(recursive: true);
      f.writeAsStringSync(jsonEncode(entries));
    }

    test('"delete forever" never deletes outside the trash folder', () async {
      final victim = File(p.join(outside.path, 'victim.txt'))
        ..writeAsStringSync('keep me');
      await writeIndex([
        {
          'id': 'abc',
          'name': 'victim.txt',
          'originalPath': victim.path,
          'trashedPath': victim.path, // crafted: points outside the trash
          'isDir': false,
          'deletedAt': DateTime.now().toIso8601String(),
        }
      ]);
      await repo.deleteForever('abc');
      expect(victim.existsSync(), isTrue);
    });

    test('restore never writes outside the workspace', () async {
      final trashed =
          File(p.join(ws.path, '.clipboard', 'trash', 'abc__evil.bat'))
            ..createSync(recursive: true)
            ..writeAsStringSync('payload');
      final target = p.join(outside.path, 'Startup', 'evil.bat');
      Directory(p.dirname(target)).createSync(recursive: true);
      await writeIndex([
        {
          'id': 'abc',
          'name': 'evil.bat',
          'originalPath': target,
          'trashedPath': trashed.path,
          'isDir': false,
          'deletedAt': DateTime.now().toIso8601String(),
        }
      ]);
      await repo.restoreFromTrash('abc');
      expect(File(target).existsSync(), isFalse);
      expect(File(p.join(ws.path, 'evil.bat')).existsSync(), isTrue);
    });

    test('a path-traversal name cannot escape the trash folder', () {
      final store = TrashStore(ws.path);
      final resolved = store.resolve(TrashEntry(
        id: '../../x',
        name: '../../../etc/passwd',
        originalPath: '',
        trashedPath: '',
        isDir: false,
        deletedAt: DateTime.now(),
      ));
      expect(p.isWithin(store.trashDir.path, resolved), isTrue);
    });

    test('a corrupt index is backed up, never silently overwritten', () async {
      final index = File(p.join(ws.path, '.clipboard', 'trash.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync('{ not json');
      final entry = TrashEntry(
        id: 'n',
        name: 'n.md',
        originalPath: p.join(ws.path, 'n.md'),
        trashedPath: '',
        isDir: false,
        deletedAt: DateTime.now(),
      );
      await TrashStore(ws.path).add(entry);
      expect(File('${index.path}.corrupt').readAsStringSync(), '{ not json');
    });
  });

  group('metadata store', () {
    test('quick successive changes are all kept (no lost update)', () async {
      final store = MetadataStore(ws.path);
      final file = p.join(ws.path, 'a.md');
      await Future.wait([
        store.setFavorite(file, true),
        store.setTags(file, ['x', 'y']),
        store.setNoteSeparator(file, '#####'),
      ]);
      final meta = await store.get(file);
      expect(meta.favorite, isTrue);
      expect(meta.tags, ['x', 'y']);
      expect(meta.noteSeparator, isNotNull);
    });

    test('writes leave no temp file behind', () async {
      final store = MetadataStore(ws.path);
      await store.setFavorite(p.join(ws.path, 'a.md'), true);
      final names = Directory(p.join(ws.path, '.clipboard'))
          .listSync()
          .map((e) => p.basename(e.path))
          .toList();
      expect(names, ['metadata.json']);
    });
  });

  group('cleaner resists hostile files', () {
    Future<CleanReport> run(String name, Uint8List data) async {
      final src = File(p.join(outside.path, name))..writeAsBytesSync(data);
      final out = Directory(p.join(outside.path, 'out'))..createSync();
      return const CleanPipeline()
          .run(src.path, out)
          .timeout(const Duration(seconds: 20));
    }

    test('an MP4 claiming billions of samples is refused fast, not allocated',
        () async {
      final data = mp4WithMetadata();
      final stsz = indexOfBytes(data, 'stsz'.codeUnits);
      putU32be(data, stsz + 12, 0xFFFFFFFF); // sample_count
      final stsc = indexOfBytes(data, 'stsc'.codeUnits);
      putU32be(data, stsc + 16, 0xFFFFFFFF); // samples_per_chunk
      final sw = Stopwatch()..start();
      final r = await run('bomb.mp4', data);
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
      // Cleaned without the SEI scrub (caveat) or refused — never a crash.
      expect(r.status, isNot(CleanStatus.residualFound));
    });

    test('a PDF with object number 999999999 cannot force a gigabyte xref',
        () async {
      final data = cat([
        asc('%PDF-1.4\n'),
        pdfObj(1, '<< /Type /Catalog /Pages 999999999 0 R >>'),
        pdfObj(999999999, '<< /Type /Pages /Kids [] /Count 0 >>'),
        asc('trailer\n<< /Root 1 0 R >>\n'),
      ]);
      final r = await run('big.pdf', data);
      expect(r.status, CleanStatus.unsupported);
      expect(r.outputPath, isNull);
    });

    test('a file too big for in-memory cleaning is refused, not loaded',
        () async {
      final f = File(p.join(outside.path, 'huge.jpg'));
      final raf = f.openSync(mode: FileMode.write)
        ..writeFromSync([0xFF, 0xD8, 0xFF, 0xE0])
        ..truncateSync(170 * 1024 * 1024); // sparse
      raf.closeSync();
      final out = Directory(p.join(outside.path, 'out'))..createSync();
      final r = await const CleanPipeline().run(f.path, out);
      expect(r.status, CleanStatus.unsupported);
      expect(r.outputPath, isNull);
    });
  });

  group('reseller web view hardening', () {
    test('the session probe carries a per-controller nonce', () {
      final js = ResellerConfig.sessionProbe('abc123');
      expect(js, contains("n: 'abc123'"));
      expect(js, contains('/api/auth/session'));
    });

    test('dangerous schemes are never handed to the system', () {
      for (final s in ['intent', 'file', 'javascript', 'data', 'content']) {
        expect(ResellerConfig.externalSchemes.contains(s), isFalse, reason: s);
      }
      expect(ResellerConfig.externalSchemes,
          containsAll(['https', 'mailto', 'tel']));
    });
  });
}
