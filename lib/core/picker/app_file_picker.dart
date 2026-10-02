import 'package:file_picker/file_picker.dart' as native;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import '../../features/library/domain/library_entry.dart';
import 'pick_mode.dart';
// The in-app browser needs dart:io, which does not compile for web. Pick the
// real implementation on desktop/mobile and a stub on web.
import 'browser_launcher_stub.dart'
    if (dart.library.io) 'browser_launcher_io.dart' as launcher;

/// Entry point for choosing files or a folder.
///
/// On desktop/mobile, media picks use the platform-native picker. Directory and
/// library import flows keep the app browser because they need folder browsing
/// and import/move actions.
abstract final class AppFilePicker {
  /// Returns the selected absolute paths (empty if the user cancels). For
  /// [PickMode.directory] the list holds at most one path.
  static Future<List<String>> pick(
    BuildContext context, {
    required PickMode mode,
    bool allowMultiple = true,
    String? title,
    String? initialDirectory,
    String? actionLabel,
  }) {
    if (kIsWeb || mode == PickMode.imageFiles || mode == PickMode.mediaFiles) {
      return _native(mode, allowMultiple, title);
    }
    return launcher.launchInAppBrowser(
      context,
      mode: mode,
      allowMultiple: allowMultiple,
      title: title,
      initialDirectory: initialDirectory,
      actionLabel: actionLabel,
    );
  }

  /// Opens the file picker for importing into the library. Desktop/mobile show
  /// Import and Move actions on the picker page itself; web falls back to a
  /// copy-style import because the browser cannot move local files.
  static Future<({List<String> paths, bool move})> pickForImport(
    BuildContext context, {
    String? title,
  }) async {
    if (kIsWeb) {
      return (paths: await _native(PickMode.files, true, title), move: false);
    }
    return launcher.launchInAppBrowserForImport(context, title: title);
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
    final mediaExtensions = [
      ...imageExtensions,
      ...videoExtensions,
      ...cleanableDocumentExtensions,
    ].map((ext) => ext.replaceFirst('.', '')).toList();
    final type = switch (mode) {
      PickMode.imageFiles => native.FileType.image,
      PickMode.mediaFiles => native.FileType.custom,
      _ => native.FileType.any,
    };
    final result = await native.FilePicker.pickFiles(
      type: type,
      allowedExtensions: mode == PickMode.mediaFiles ? mediaExtensions : null,
      allowMultiple: allowMultiple,
      dialogTitle: title,
    );
    return result?.files.map((f) => f.path).whereType<String>().toList() ??
        const [];
  }
}
