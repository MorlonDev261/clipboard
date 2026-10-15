import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/services/atomic_file.dart';
import '../domain/ledger_entry.dart';

/// Reads and writes `<root>/.clipboard/accounting.json` — the ledger lives in
/// the workspace folder, never in the app's own storage.
class AccountingStore {
  AccountingStore(this.root);

  final String root;
  final _lock = AsyncMutex();

  File get _file => File(p.join(root, '.clipboard', 'accounting.json'));

  Future<List<LedgerEntry>> load() async {
    try {
      if (!await _file.exists()) return [];
      final data = jsonDecode(await _file.readAsString(encoding: utf8));
      final list = data is Map ? data['entries'] : null;
      if (list is! List) return [];
      return [
        for (final raw in list)
          if (LedgerEntry.tryFromJson(raw) case final e?) e,
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _mutate(void Function(List<LedgerEntry> entries) change) =>
      _lock.run(() async {
        final entries = await load();
        change(entries);
        await writeStringAtomic(
          _file,
          const JsonEncoder.withIndent('  ').convert({
            'version': 1,
            'entries': [for (final e in entries) e.toJson()],
          }),
        );
      });

  /// Inserts the entry, or replaces the one with the same id.
  Future<void> upsert(LedgerEntry entry) => _mutate((entries) {
        final i = entries.indexWhere((e) => e.id == entry.id);
        if (i >= 0) {
          entries[i] = entry;
        } else {
          entries.add(entry);
        }
      });

  Future<void> remove(String id) =>
      _mutate((entries) => entries.removeWhere((e) => e.id == id));
}
