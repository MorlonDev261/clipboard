import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists the path of the user's chosen workspace (library) folder.
///
/// The path is stored in a tiny JSON config file in the app support directory,
/// so it survives restarts. The workspace folder itself lives wherever the
/// user picked it on disk.
class WorkspaceService {
  static const _fileName = 'clipboard_config.json';
  static const _rootKey = 'rootPath';

  Future<File> _configFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Returns the saved workspace path, or null if none is set yet (or the
  /// folder no longer exists).
  Future<String?> loadRoot() async {
    try {
      final file = await _configFile();
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return null;
      final path = data[_rootKey];
      if (path is! String || path.isEmpty) return null;
      if (!await Directory(path).exists()) return null;
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRoot(String path) async {
    final file = await _configFile();
    await file.writeAsString(jsonEncode({_rootKey: path}));
  }
}
