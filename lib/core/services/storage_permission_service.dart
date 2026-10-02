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

  Future<bool> requestStorageAccess() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('requestStorageAccess') ?? false;
    } catch (_) {
      return false;
    }
  }
}
