import 'package:clipboard/core/l10n/app_strings.dart';
import 'package:clipboard/features/library/domain/library_entry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Lightweight, dependency-free tests (no filesystem, no UI boot).
void main() {
  group('AppStrings', () {
    test('defaults to French', () {
      const strings = AppStrings(Locale('fr'));
      expect(strings.home, 'Accueil');
      expect(strings.newFolder, 'Nouveau dossier');
    });

    test('falls back to English', () {
      const strings = AppStrings(Locale('en'));
      expect(strings.home, 'Home');
      expect(strings.trash, 'Trash');
    });
  });

  group('kindForFile', () {
    test('classifies by extension', () {
      expect(kindForFile('photo.JPG'), EntryKind.image);
      expect(kindForFile('clip.mp4'), EntryKind.video);
      expect(kindForFile('note.md'), EntryKind.note);
      expect(kindForFile('archive.zip'), EntryKind.other);
    });
  });

  group('LibraryEntry', () {
    test('displayName strips the .md extension for notes', () {
      final note = LibraryEntry(
        path: '/lib/hello.md',
        name: 'hello.md',
        kind: EntryKind.note,
        size: 12,
        modified: DateTime(2026),
      );
      expect(note.displayName, 'hello');

      final image = LibraryEntry(
        path: '/lib/pic.png',
        name: 'pic.png',
        kind: EntryKind.image,
        size: 1000,
        modified: DateTime(2026),
      );
      expect(image.displayName, 'pic.png');
      expect(image.isMedia, isTrue);
    });
  });
}
