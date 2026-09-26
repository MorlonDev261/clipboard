import 'package:clipboard/core/l10n/app_strings.dart';
import 'package:clipboard/features/folders/domain/folder.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Lightweight, dependency-free tests that do not touch the database.
// Widget/integration tests that boot the full app arrive in a later milestone.
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

  group('Folder', () {
    final now = DateTime(2026);
    final folder = Folder(
      id: 'f1',
      name: 'Main',
      isRoot: true,
      createdAt: now,
      updatedAt: now,
    );

    test('copyWith updates the name and keeps identity', () {
      final renamed = folder.copyWith(name: 'Renamed');
      expect(renamed.name, 'Renamed');
      expect(renamed.id, folder.id);
      expect(renamed == folder, isTrue); // equality is by id
    });

    test('isDeleted reflects deletedAt', () {
      expect(folder.isDeleted, isFalse);
      final deleted = folder.copyWith(deletedAt: () => now);
      expect(deleted.isDeleted, isTrue);
    });
  });
}
