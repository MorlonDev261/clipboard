import 'package:clipboard/features/library/application/browse_filtering.dart';
import 'package:clipboard/features/library/domain/library_entry.dart';
import 'package:clipboard/shared/enums/enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Builds a fake recursive listing (paths only) the way
/// LibraryRepository.listAllUnder would: a folder entry per directory and a
/// file entry per file, all with absolute paths. Uses POSIX-style paths, which
/// package:path handles natively on the test host.
LibraryEntry _folder(String path) => LibraryEntry(
      path: path,
      name: p.basename(path),
      kind: EntryKind.folder,
      size: 0,
      modified: DateTime(2020),
    );

LibraryEntry _file(String path) => LibraryEntry(
      path: path,
      name: p.basename(path),
      kind: kindForFile(p.basename(path)),
      size: 1,
      modified: DateTime(2020),
    );

List<String> _paths(List<LibraryEntry> entries) =>
    entries.map((e) => e.path).toList();

void main() {
  const dir = '/w';

  group('entriesForFilter (image)', () {
    test('shows direct files first, then containing folders by proximity', () {
      // /w
      //   Dossier 1/                              (no image)
      //   Dossier 2/sous1/soussous/img.jpg        (image, depth 4)
      //   Dossier 3/sous1/img.jpg                 (image, depth 3)
      //   fichier img 1.jpg                        (image, depth 1)
      //   fichier img 2.jpg                        (image, depth 1)
      final recursive = <LibraryEntry>[
        _folder('/w/Dossier 1'),
        _folder('/w/Dossier 2'),
        _folder('/w/Dossier 2/sous1'),
        _folder('/w/Dossier 2/sous1/soussous'),
        _file('/w/Dossier 2/sous1/soussous/img.jpg'),
        _folder('/w/Dossier 3'),
        _folder('/w/Dossier 3/sous1'),
        _file('/w/Dossier 3/sous1/img.jpg'),
        _file('/w/fichier img 1.jpg'),
        _file('/w/fichier img 2.jpg'),
      ];

      final result = entriesForFilter(recursive, dir, EntryKind.image);

      expect(_paths(result), [
        '/w/fichier img 1.jpg',
        '/w/fichier img 2.jpg',
        '/w/Dossier 3', // nearest match at depth 3
        '/w/Dossier 2', // nearest match at depth 4
      ]);
    });

    test('omits folders that contain no match', () {
      final recursive = <LibraryEntry>[
        _folder('/w/Empty'),
        _folder('/w/Empty/deeper'),
        _file('/w/Empty/deeper/notes.md'),
        _folder('/w/HasImage'),
        _file('/w/HasImage/pic.png'),
      ];

      final result = entriesForFilter(recursive, dir, EntryKind.image);

      expect(_paths(result), ['/w/HasImage']);
    });

    test('uses the shallowest match to rank a folder', () {
      // A folder holds one shallow and one deep image; ranking uses the shallow
      // one, so it beats a folder whose only match is deeper.
      final recursive = <LibraryEntry>[
        _folder('/w/A'),
        _file('/w/A/near.png'), // depth 2
        _folder('/w/A/deep'),
        _file('/w/A/deep/far.png'), // depth 3
        _folder('/w/B'),
        _folder('/w/B/x'),
        _file('/w/B/x/only.png'), // depth 3
      ];

      final result = entriesForFilter(recursive, dir, EntryKind.image);

      expect(_paths(result), ['/w/A', '/w/B']);
    });

    test('surfaces the direct child for media attached to a note deeper down',
        () {
      // Note attachments live in a hidden `.attachments` folder that is never
      // itself a listed folder entry; the match must still surface Dossier.
      final recursive = <LibraryEntry>[
        _folder('/w/Dossier'),
        _folder('/w/Dossier/sub'),
        _file('/w/Dossier/sub/.attachments/pic.jpg'),
      ];

      final result = entriesForFilter(recursive, dir, EntryKind.image);

      expect(_paths(result), ['/w/Dossier']);
    });

    test('skips the current folder\'s own hidden attachments', () {
      final recursive = <LibraryEntry>[
        _file('/w/.attachments/pic.jpg'),
        _folder('/w/Real'),
        _file('/w/Real/pic.png'),
      ];

      final result = entriesForFilter(recursive, dir, EntryKind.image);

      // Only the folder with a real, browsable image — the current folder's own
      // hidden attachment is not a surfaceable entry.
      expect(_paths(result), ['/w/Real']);
    });
  });

  group('entriesForFilter (folder)', () {
    test('lists the direct sub-folders by name', () {
      final recursive = <LibraryEntry>[
        _folder('/w/Beta'),
        _folder('/w/Alpha'),
        _folder('/w/Alpha/nested'), // not a direct child
        _file('/w/loose.png'),
      ];

      final result = entriesForFilter(recursive, dir, EntryKind.folder);

      expect(_paths(result), ['/w/Alpha', '/w/Beta']);
    });
  });

  group('sortEntries', () {
    test('puts folders first, then sorts by name ascending', () {
      final entries = <LibraryEntry>[
        _file('/w/b.png'),
        _folder('/w/Zeta'),
        _file('/w/a.png'),
        _folder('/w/Alpha'),
      ];

      final result = sortEntries(entries, SortOption.nameAsc);

      expect(_paths(result), ['/w/Alpha', '/w/Zeta', '/w/a.png', '/w/b.png']);
    });
  });
}
