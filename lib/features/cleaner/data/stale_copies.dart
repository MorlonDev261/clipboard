import 'dart:io';

import 'package:path/path.dart' as p;

/// Cleaned copies are named `<name>_clean_<microseconds since epoch><ext>`
/// (see `CleanPipeline`). If the app is killed before the user saves or discards
/// one, it would sit in the temp folder indefinitely — a clean copy of a private
/// photo, taking space. This removes the old ones.
final _cleanCopyName = RegExp(r'^.+_clean_(\d{16})\.[A-Za-z0-9]{1,8}$');

/// Deletes cleaned copies older than [olderThan] directly inside [dir].
/// Only files whose name matches the pattern *and* whose embedded timestamp is
/// old enough are touched. Returns how many were removed.
Future<int> purgeStaleCleanCopies(
  Directory dir, {
  DateTime? now,
  Duration olderThan = const Duration(days: 1),
}) async {
  var removed = 0;
  try {
    if (!await dir.exists()) return 0;
    final cutoff = (now ?? DateTime.now()).subtract(olderThan);
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File) continue;
      final m = _cleanCopyName.firstMatch(p.basename(e.path));
      if (m == null) continue;
      final micros = int.tryParse(m.group(1)!);
      if (micros == null) continue;
      final created = DateTime.fromMicrosecondsSinceEpoch(micros);
      if (created.isAfter(cutoff)) continue;
      try {
        await e.delete();
        removed++;
      } catch (_) {
        // in use or already gone: leave it for next time
      }
    }
  } catch (_) {
    // the temp folder is best-effort housekeeping, never a reason to fail
  }
  return removed;
}
