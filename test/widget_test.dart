import 'package:clipboard/core/l10n/app_strings.dart';
import 'package:clipboard/features/library/application/library_providers.dart';
import 'package:clipboard/features/library/domain/library_entry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Lightweight, dependency-free tests (no filesystem, no UI boot).
void main() {
  group('AppStrings', () {
    test('supports French', () {
      const strings = AppStrings(Locale('fr'));
      expect(strings.home, 'Accueil');
      expect(strings.newFolder, 'Nouveau dossier');
    });

    test('supports English', () {
      const strings = AppStrings(Locale('en'));
      expect(strings.home, 'Home');
      expect(strings.trash, 'Trash');
    });

    test('supports Malagasy and branded app name', () {
      const strings = AppStrings(Locale('mg'));
      expect(strings.home, 'Fandraisana');
      expect(strings.add, 'Ampio');
      expect(strings.appName, 'Influencor');
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

  group('Selection and Preview providers', () {
    test('selectedEntriesProvider tracks selected paths', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedEntriesProvider), isEmpty);

      container.read(selectedEntriesProvider.notifier).state = {
        '/lib/pic1.png'
      };
      expect(
          container.read(selectedEntriesProvider), contains('/lib/pic1.png'));

      container.read(selectedEntriesProvider.notifier).state = {
        '/lib/pic1.png',
        '/lib/pic2.png',
      };
      expect(container.read(selectedEntriesProvider).length, 2);

      // Deselect
      final current = Set<String>.from(container.read(selectedEntriesProvider));
      current.remove('/lib/pic1.png');
      container.read(selectedEntriesProvider.notifier).state = current;
      expect(
          container.read(selectedEntriesProvider), equals({'/lib/pic2.png'}));
    });

    test('supports new localization strings for preview and selection', () {
      const stringsFr = AppStrings(Locale('fr'));
      expect(stringsFr.deselectAction, 'Désélectionner');
      expect(stringsFr.previous, 'Précédent');
      expect(stringsFr.next, 'Suivant');

      const stringsEn = AppStrings(Locale('en'));
      expect(stringsEn.deselectAction, 'Deselect');
      expect(stringsEn.previous, 'Previous');
      expect(stringsEn.next, 'Next');
    });
  });
}
