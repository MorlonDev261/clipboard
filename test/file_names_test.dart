import 'dart:io';

import 'package:clipboard/features/library/data/file_names.dart';
import 'package:clipboard/features/library/data/library_repository.dart';
import 'package:clipboard/features/library/data/metadata_store.dart';
import 'package:clipboard/features/library/data/trash_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('sanitizeFileName', () {
    test('separators, forbidden and control characters become underscores', () {
      expect(sanitizeFileName(r'a/b\c:d*e?f"g<h>i|j'), 'a_b_c_d_e_f_g_h_i_j');
      expect(sanitizeFileName('tab\there\nnewline'), 'tab_here_newline');
    });

    test('"." and ".." can never address another folder', () {
      expect(sanitizeFileName('.'), isNot('.'));
      expect(sanitizeFileName('..'), isNot('..'));
      expect(sanitizeFileName('../../etc'), isNot(contains('/')));
    });

    test(
        'leading dots are removed: dot-names are hidden or reserved by the app',
        () {
      expect(sanitizeFileName('.clipboard'), '_clipboard');
      expect(sanitizeFileName('.attachments'), '_attachments');
      expect(sanitizeFileName('...x'), '_x');
    });

    test('no trailing dot or space (Windows would strip them)', () {
      expect(sanitizeFileName('note. . '), 'note');
      expect(sanitizeFileName('   '), 'Sans titre');
    });

    test('Windows device names are prefixed, with or without extension', () {
      for (final n in ['CON', 'nul', 'Com1', 'LPT9', 'aux.txt', 'PRN.tar.gz']) {
        expect(sanitizeFileName(n).startsWith('_'), isTrue, reason: n);
      }
      // Near misses are fine.
      expect(sanitizeFileName('CONSOLE'), 'CONSOLE');
      expect(sanitizeFileName('COM10'), 'COM10');
      expect(sanitizeFileName('NULL'), 'NULL');
    });

    test('is capped without splitting an emoji', () {
      final long = '${'a' * 118}😀😀';
      final out = sanitizeFileName(long);
      expect(out.length, lessThanOrEqualTo(120));
      // Valid UTF-16: round-trips through code points unchanged.
      expect(String.fromCharCodes(out.runes), out);
    });

    test('ordinary names are untouched (accents, spaces, emoji)', () {
      expect(sanitizeFileName('Idée n°1 — été 😀'), 'Idée n°1 — été 😀');
    });
  });

  group('the repository uses it everywhere', () {
    late Directory ws;
    late LibraryRepository repo;

    setUp(() async {
      ws = await Directory.systemTemp.createTemp('names_ws_');
      repo = LibraryRepository(
        root: ws.path,
        metadata: MetadataStore(ws.path),
        trash: TrashStore(ws.path),
      );
    });

    tearDown(() async {
      if (await ws.exists()) await ws.delete(recursive: true);
    });

    test('createFolder / createNote / rename produce listable, safe names',
        () async {
      final folder = await repo.createFolder(ws.path, '.clipboard');
      expect(p.basename(folder), '_clipboard');

      final note = await repo.createNote(ws.path, title: 'NUL', content: 'x');
      expect(p.basename(note), '_NUL.md');

      final renamed = await repo.rename(note, '..');
      expect(p.dirname(renamed), ws.path);
      expect(p.basename(renamed).startsWith('.'), isFalse);
    });
  });
}
