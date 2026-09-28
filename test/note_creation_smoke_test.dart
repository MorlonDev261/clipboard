import 'dart:io';

import 'package:clipboard/features/library/data/library_repository.dart';
import 'package:clipboard/features/library/data/metadata_store.dart';
import 'package:clipboard/features/library/data/trash_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late LibraryRepository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('clipboard_note_test_');
    repo = LibraryRepository(
      root: tmp.path,
      metadata: MetadataStore(tmp.path),
      trash: TrashStore(tmp.path),
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('createNote writes a real .md file with the given content', () async {
    final path = await repo.createNote(
      tmp.path,
      title: 'My First Note',
      content: 'Hello world',
    );

    expect(await File(path).exists(), isTrue);
    expect(path.endsWith('My First Note.md'), isTrue);
    expect(await File(path).readAsString(), 'Hello world');
  });

  test('createNote falls back to "Note" when title is blank', () async {
    final path = await repo.createNote(tmp.path, title: '', content: 'x');
    expect(path.endsWith('Note.md'), isTrue);
  });

  test('createNote avoids collisions by incrementing', () async {
    final p1 = await repo.createNote(tmp.path, title: 'Dup', content: 'a');
    final p2 = await repo.createNote(tmp.path, title: 'Dup', content: 'b');
    expect(p1, isNot(equals(p2)));
    expect(await File(p1).readAsString(), 'a');
    expect(await File(p2).readAsString(), 'b');
  });

  test('createNote sanitizes illegal filename characters', () async {
    final path = await repo.createNote(
      tmp.path,
      title: 'Weird:/Name*?',
      content: 'x',
    );
    expect(await File(path).exists(), isTrue);
  });

  test('readTextFile / writeTextFile round-trip an edited note', () async {
    final path = await repo.createNote(
      tmp.path,
      title: 'Editable',
      content: 'v1',
    );
    expect(await repo.readTextFile(path), 'v1');
    await repo.writeTextFile(path, 'v2');
    expect(await repo.readTextFile(path), 'v2');
  });

  test('listEntries surfaces the newly created note', () async {
    await repo.createNote(tmp.path, title: 'Listed', content: 'x');
    final entries = await repo.listEntries(tmp.path);
    expect(entries.any((e) => e.path.endsWith('Listed.md')), isTrue);
  });
}
