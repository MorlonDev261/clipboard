import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/workspace_service.dart';

final workspaceServiceProvider = Provider<WorkspaceService>((ref) {
  return WorkspaceService();
});

/// Holds the current workspace root path (null until the user picks one).
class WorkspaceController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() {
    return ref.watch(workspaceServiceProvider).loadRoot();
  }

  Future<void> setRoot(String path) async {
    await ref.read(workspaceServiceProvider).saveRoot(path);
    state = AsyncData(path);
  }
}

final workspaceControllerProvider =
    AsyncNotifierProvider<WorkspaceController, String?>(WorkspaceController.new);

/// Convenience: the current root path, or null.
final workspaceRootProvider = Provider<String?>((ref) {
  return ref.watch(workspaceControllerProvider).valueOrNull;
});
