import 'dart:io';

import 'package:flutter/services.dart';

class StoragePermissionService {
  static const _channel =
      MethodChannel('com.influencor.app/storage_permissions');

  Future<bool> hasStorageAccess() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasStorageAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks Android to index [paths] in MediaStore (gallery, share pickers).
  /// Best effort: never throws, no-op off Android.
  Future<void> scanMedia(List<String> paths) async {
    if (!Platform.isAndroid || paths.isEmpty) return;
    try {
      await _channel.invokeMethod<bool>('scanMedia', {'paths': paths});
    } catch (_) {}
  }

  Future<bool> requestStorageAccess() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('requestStorageAccess') ?? false;
    } catch (_) {
      return false;
    }
  }
}
