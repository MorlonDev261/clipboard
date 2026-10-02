import 'dart:io';

import 'package:clipboard/core/services/storage_permission_service.dart';
import 'package:clipboard/core/services/workspace_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FakePermission extends StoragePermissionService {
  int requests = 0;
  bool grant = false;

  @override
  Future<bool> requestStorageAccess() async {
    requests++;
    return grant;
  }
}

void main() {
  late Directory base;
  late _FakePermission permission;
  late WorkspaceService service;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('ws_perm_');
    permission = _FakePermission();
    service = WorkspaceService(
      storagePermissionService: permission,
      isMobile: true, // exercise the Android/iOS branch on any host
      appFolderBase: () async => Directory(p.join(base.path, 'app-private')),
      configBase: () async => Directory(p.join(base.path, 'config')),
    );
  });

  tearDown(() async {
    if (await base.exists()) await base.delete(recursive: true);
  });

  test('a writable folder is accepted WITHOUT asking for broad access',
      () async {
    final folder = Directory(p.join(base.path, 'mine'))..createSync();
    expect(await service.saveRoot(folder.path), folder.path);
    expect(permission.requests, 0);
    expect(await service.loadRoot(), folder.path);
  });

  test('an unusable folder triggers one request; refusal leaves no workspace',
      () async {
    // A path *below a regular file* can never be created or written.
    final file = File(p.join(base.path, 'file.txt'))..writeAsStringSync('x');
    final blocked = p.join(file.path, 'sub');

    expect(await service.saveRoot(blocked), isNull);
    expect(permission.requests, 1);
    expect(await service.loadRoot(), isNull);
  });

  test('the app folder works with no permission at all', () async {
    final path = await service.appFolderPath();
    expect(p.basename(path), 'Influencor');
    expect(Directory(path).existsSync(), isTrue);

    expect(await service.saveRoot(path), path);
    expect(permission.requests, 0);
  });

  test('refusing access never overwrites a previously saved workspace',
      () async {
    final good = Directory(p.join(base.path, 'good'))..createSync();
    await service.saveRoot(good.path);

    final file = File(p.join(base.path, 'f.txt'))..writeAsStringSync('x');
    expect(await service.saveRoot(p.join(file.path, 'nope')), isNull);

    expect(await service.loadRoot(), good.path);
  });
}
