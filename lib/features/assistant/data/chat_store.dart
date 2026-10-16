import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/services/atomic_file.dart';

/// Keeps the current Degany conversation between launches, as JSON in the app
/// support directory (on this device only, never in the workspace).
class ChatStore {
  ChatStore({Future<File> Function()? file}) : _fileOverride = file;

  final Future<File> Function()? _fileOverride;

  static const _fileName = 'assistant_chat.json';

  Future<File> _file() async {
    if (_fileOverride case final override?) return override();
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// The saved conversation, or null if there is none (or it is unreadable).
  Future<Map<String, dynamic>?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString(encoding: utf8));
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  /// Best effort: a failed save never disturbs the chat.
  Future<void> save(Map<String, dynamic> data) async {
    try {
      await writeStringAtomic(await _file(), jsonEncode(data));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
