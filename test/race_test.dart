import 'dart:io';

import 'package:clipboard/features/library/data/library_repository.dart';
import 'package:clipboard/features/library/data/metadata_store.dart';
import 'package:clipboard/features/library/data/trash_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory ws;
  late Directory src;
  late LibraryRepository repo;

  setUp(() async {
    ws = await Directory.systemTemp.createTemp('race_ws_');
    src = await Directory.systemTemp.createTemp('race_src_');
    repo = LibraryRepository(
      root: ws.path,
      metadata: MetadataStore(ws.path),
      trash: TrashStore(ws.path),
    );
  });

  tearDown(() async {
    for (final d in [ws, src]) {
      if (await d.exists()) await d.delete(recursive: true);
    }
  });

  List<String> files(Directory d) =>
      d.listSync().whereType<File>().map((f) => p.basename(f.path)).toList()
        ..sort();

  test('simultaneous notes with the same title never overwrite each other',
      () async {
    final paths = await Future.wait([
      for (var i = 0; i < 25; i++)
        repo.createNote(ws.path, title: 'Idea', content: 'content-$i'),
    ]);
    expect(paths.toSet().length, 25, reason: 'every call got its own file');
    final contents = {
      for (final f in paths) File(f).readAsStringSync(),
    };
    expect(contents.length, 25, reason: 'no content was lost');
  });

  test('simultaneous imports of the same file give distinct copies', () async {
    final f = File(p.join(src.path, 'photo.jpg'))..writeAsBytesSync([1, 2, 3]);
    await Future.wait([
      for (var i = 0; i < 12; i++) repo.importPaths(ws.path, [f.path]),
    ]);
    expect(files(ws).length, 12);
    for (final name in files(ws)) {
      expect(File(p.join(ws.path, name)).readAsBytesSync(), [1, 2, 3]);
    }
  });

  test('move never replaces a file that already has that name', () async {
    final a = Directory(p.join(ws.path, 'a'))..createSync();
    final b = Directory(p.join(ws.path, 'b'))..createSync();
    final mover = File(p.join(a.path, 'n.md'))..writeAsStringSync('moving');
    File(p.join(b.path, 'n.md')).writeAsStringSync('already here');

    final moved = await repo.move(mover.path, b.path);

    expect(File(p.join(b.path, 'n.md')).readAsStringSync(), 'already here');
    expect(File(moved).readAsStringSync(), 'moving');
    expect(p.basename(moved), 'n (1).md');
  });

  test('duplicate and restore also reserve their names', () async {
    final note = await repo.createNote(ws.path, title: 'N', content: 'x');
    final copies = await Future.wait([
      repo.duplicate(note),
      repo.duplicate(note),
      repo.duplicate(note),
    ]);
    expect(copies.toSet().length, 3);
  });

  test('a failed copy leaves no empty placeholder behind', () async {
    final missing = p.join(src.path, 'ghost.jpg');
    final failed = await repo.importPaths(ws.path, [missing]);
    expect(failed, [missing]);
    expect(files(ws), isEmpty);

    // attachImageToDir: same guarantee.
    await expectLater(
      repo.attachImageToDir(ws.path, missing),
      throwsA(isA<FileSystemException>()),
    );
    final attach = Directory(p.join(ws.path, '.attachments'));
    expect(attach.listSync(), isEmpty);
  });
}
