import 'dart:io';

import 'package:clipboard/features/library/data/library_repository.dart';
import 'package:clipboard/features/library/data/metadata_store.dart';
import 'package:clipboard/features/library/data/trash_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory workspace;
  late Directory outside;
  late LibraryRepository repo;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('clipboard_import_ws_');
    outside = await Directory.systemTemp.createTemp('clipboard_import_src_');
    repo = LibraryRepository(
      root: workspace.path,
      metadata: MetadataStore(workspace.path),
      trash: TrashStore(workspace.path),
    );
  });

  tearDown(() async {
    for (final dir in [workspace, outside]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('importPaths copies a file into the destination', () async {
    final src = File(p.join(outside.path, 'photo.jpg'))
      ..writeAsBytesSync([1, 2, 3]);

    final failed = await repo.importPaths(workspace.path, [src.path]);

    expect(failed, isEmpty);
    final copy = File(p.join(workspace.path, 'photo.jpg'));
    expect(await copy.exists(), isTrue);
    expect(await copy.readAsBytes(), [1, 2, 3]);
    // Source untouched — import copies, it doesn't move.
    expect(await src.exists(), isTrue);
  });

  test('importPaths copies a whole folder recursively', () async {
    final srcDir = Directory(p.join(outside.path, 'album'))..createSync();
    File(p.join(srcDir.path, 'a.png')).writeAsBytesSync([1]);
    final nested = Directory(p.join(srcDir.path, 'nested'))..createSync();
    File(p.join(nested.path, 'b.png')).writeAsBytesSync([2]);

    final failed = await repo.importPaths(workspace.path, [srcDir.path]);

    expect(failed, isEmpty);
    expect(
        await File(p.join(workspace.path, 'album', 'a.png')).exists(), isTrue);
    expect(
        await File(p.join(workspace.path, 'album', 'nested', 'b.png'))
            .exists(),
        isTrue);
  });

  test('importPaths avoids collisions by incrementing the copy name',
      () async {
    File(p.join(workspace.path, 'doc.txt')).writeAsStringSync('existing');
    final src = File(p.join(outside.path, 'doc.txt'))
      ..writeAsStringSync('incoming');

    final failed = await repo.importPaths(workspace.path, [src.path]);

    expect(failed, isEmpty);
    expect(await File(p.join(workspace.path, 'doc.txt')).readAsString(),
        'existing');
    expect(
        await File(p.join(workspace.path, 'doc (1).txt')).readAsString(),
        'incoming');
  });

  test('importPaths reports missing sources as failed without throwing',
      () async {
    final missing = p.join(outside.path, 'does_not_exist.txt');

    final failed = await repo.importPaths(workspace.path, [missing]);

    expect(failed, [missing]);
  });

  test('importPaths imports several files in one call, skipping failures',
      () async {
    final ok1 = File(p.join(outside.path, 'one.txt'))
      ..writeAsStringSync('1');
    final ok2 = File(p.join(outside.path, 'two.txt'))
      ..writeAsStringSync('2');
    final missing = p.join(outside.path, 'missing.txt');

    final failed = await repo.importPaths(
      workspace.path,
      [ok1.path, missing, ok2.path],
    );

    expect(failed, [missing]);
    expect(await File(p.join(workspace.path, 'one.txt')).exists(), isTrue);
    expect(await File(p.join(workspace.path, 'two.txt')).exists(), isTrue);
  });
}
