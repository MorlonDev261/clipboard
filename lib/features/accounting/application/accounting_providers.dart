import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/workspace_providers.dart';
import '../data/accounting_store.dart';
import '../domain/ledger_entry.dart';

final accountingStoreProvider = Provider<AccountingStore?>((ref) {
  final root = ref.watch(workspaceRootProvider);
  return root == null ? null : AccountingStore(root);
});

/// Ledger entries, newest first.
class LedgerController extends AsyncNotifier<List<LedgerEntry>> {
  @override
  Future<List<LedgerEntry>> build() async {
    final store = ref.watch(accountingStoreProvider);
    if (store == null) return const [];
    return _sorted(await store.load());
  }

  static List<LedgerEntry> _sorted(List<LedgerEntry> list) =>
      [...list]..sort((a, b) => b.date.compareTo(a.date));

  Future<void> save(LedgerEntry entry) async {
    final store = ref.read(accountingStoreProvider);
    if (store == null) return;
    await store.upsert(entry);
    state = AsyncData(_sorted(await store.load()));
  }

  Future<void> remove(String id) async {
    final store = ref.read(accountingStoreProvider);
    if (store == null) return;
    await store.remove(id);
    state = AsyncData(_sorted(await store.load()));
  }
}

final ledgerProvider =
    AsyncNotifierProvider<LedgerController, List<LedgerEntry>>(
        LedgerController.new);
