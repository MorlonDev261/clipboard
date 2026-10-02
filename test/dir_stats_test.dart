import 'dart:io';

import 'package:clipboard/features/library/data/library_repository.dart';
import 'package:clipboard/features/library/data/metadata_store.dart';
import 'package:clipboard/features/library/data/trash_store.dart';
import 'package:clipboard/features/library/domain/library_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('listAllUnder counts entries in nested subfolders', () async {
    final root = Directory.systemTemp.createTempSync('stats_test');
    addTearDown(() => root.deleteSync(recursive: true));

    // root/
    //   a.md                (note)
    //   pic.png             (image)
    //   sub/                (folder)
    //     clip.mp4          (video, nested)
    //     deep/             (folder, nested)
    //       note2.md        (note, deeply nested)
    //       table.json      (compatible table, deeply nested)
    //       raw.json        (unsupported JSON, hidden)
    File(p.join(root.path, 'a.md')).writeAsStringSync('hello');
    File(p.join(root.path, 'pic.png')).writeAsBytesSync([0]);
    final sub = Directory(p.join(root.path, 'sub'))..createSync();
    File(p.join(sub.path, 'clip.mp4')).writeAsBytesSync([0]);
    final deep = Directory(p.join(sub.path, 'deep'))..createSync();
    File(p.join(deep.path, 'note2.md')).writeAsStringSync('deep');
    File(p.join(deep.path, 'table.json')).writeAsStringSync('''
{
  "type": "influencor.table",
  "version": 1,
  "columns": [{"id": "name", "title": "Name"}],
  "rows": []
}
''');
    File(p.join(deep.path, 'raw.json')).writeAsStringSync('{"raw": true}');

    final repo = LibraryRepository(
      root: root.path,
      metadata: MetadataStore(root.path),
      trash: TrashStore(root.path),
    );

    final all = await repo.listAllUnder(root.path);
    int count(bool Function(LibraryEntry) f) => all.where(f).length;

    expect(count((e) => e.isFolder), 2, reason: 'sub + deep');
    expect(count((e) => e.isImage), 1, reason: 'pic.png');
    expect(count((e) => e.isVideo), 1, reason: 'clip.mp4 in sub');
    expect(count((e) => e.isNote), 2, reason: 'a.md + deep/note2.md');
    expect(count((e) => e.isTable), 1, reason: 'compatible table only');
    expect(all.any((e) => e.name == 'raw.json'), isFalse);
  });
}
