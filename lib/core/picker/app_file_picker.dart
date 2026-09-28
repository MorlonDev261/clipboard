import 'package:file_picker/file_picker.dart' as native;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'pick_mode.dart';
// The in-app browser needs dart:io, which does not compile for web. Pick the
// real implementation on desktop/mobile and a stub on web.
import 'browser_launcher_stub.dart'
    if (dart.library.io) 'browser_launcher_io.dart' as launcher;

/// Entry point for choosing files or a folder.
///
/// On desktop and mobile it opens the app's own file browser (its design, with
/// checkboxes for multi-selection). On the web — where a browser sandbox forbids
/// filesystem access — it falls back to the platform's native picker.
abstract final class AppFilePicker {
  /// Returns the selected absolute paths (empty if the user cancels). For
  /// [PickMode.directory] the list holds at most one path.
  static Future<List<String>> pick(
    BuildContext context, {
    required PickMode mode,
    bool allowMultiple = true,
    String? title,
    String? initialDirectory,
  }) {
    if (kIsWeb) return _native(mode, allowMultiple, title);
    return launcher.launchInAppBrowser(
      context,
      mode: mode,
      allowMultiple: allowMultiple,
      title: title,
      initialDirectory: initialDirectory,
    );
  }

  static Future<List<String>> _native(
    PickMode mode,
    bool allowMultiple,
    String? title,
  ) async {
    if (mode == PickMode.directory) {
      final dir = await native.FilePicker.getDirectoryPath(dialogTitle: title);
      return dir == null ? const [] : [dir];
    }
    final type = mode == PickMode.imageFiles
        ? native.FileType.image
        : native.FileType.any;
    final result = await native.FilePicker.pickFiles(
      type: type,
      allowMultiple: allowMultiple,
      dialogTitle: title,
    );
    return result?.files.map((f) => f.path).whereType<String>().toList() ??
        const [];
  }
}
