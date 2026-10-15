import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/workspace_providers.dart';
import '../data/task_store.dart';
import '../domain/task_doc.dart';

final taskStoreProvider = Provider<TaskStore?>((ref) {
  final root = ref.watch(workspaceRootProvider);
  return root == null ? null : TaskStore(root);
});

/// All tasks. Call `ref.invalidate(taskListProvider)` after a change.
final taskListProvider = FutureProvider<List<TaskDoc>>((ref) async {
  final store = ref.watch(taskStoreProvider);
  if (store == null) return const [];
  return store.loadAll();
});
