import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_windows/flutter_secure_storage_windows.dart';
import 'package:flutter_test/flutter_test.dart';

/// The vendored Windows storage (third_party/flutter_secure_storage_windows):
/// DPAPI-encrypted, no C++ plugin.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stores secrets encrypted with DPAPI and reads them back', () async {
    final dir = await Directory.systemTemp.createTemp('influencor_secrets_');
    addTearDown(() => dir.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );

    final storage = FlutterSecureStorageWindows();
    const options = <String, String>{};
    await storage.write(
        key: 'apiKey', value: 'sk-secret-123', options: options);

    expect(
        await storage.read(key: 'apiKey', options: options), 'sk-secret-123');
    // On disk the value is encrypted, never in clear.
    final files = dir.listSync(recursive: true).whereType<File>().toList();
    expect(files, isNotEmpty);
    for (final f in files) {
      expect(String.fromCharCodes(f.readAsBytesSync()),
          isNot(contains('sk-secret-123')));
    }

    await storage.delete(key: 'apiKey', options: options);
    expect(await storage.read(key: 'apiKey', options: options), isNull);
  }, skip: !Platform.isWindows ? 'DPAPI is Windows-only' : false);
}
