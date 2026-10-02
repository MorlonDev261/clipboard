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

  /// Returns `false` when the folder could not be used (typically: storage
  /// access refused) — the previous workspace is then left untouched.
  Future<bool> setRoot(String path) async {
    final saved = await ref.read(workspaceServiceProvider).saveRoot(path);
    if (saved == null) return false;
    state = AsyncData(saved);
    return true;
  }

  /// Uses a folder in the app's own storage (needs no permission).
  Future<bool> useAppFolder() async {
    final service = ref.read(workspaceServiceProvider);
    return setRoot(await service.appFolderPath());
  }
}

final workspaceControllerProvider =
    AsyncNotifierProvider<WorkspaceController, String?>(
        WorkspaceController.new);

/// Convenience: the current root path, or null.
final workspaceRootProvider = Provider<String?>((ref) {
  return ref.watch(workspaceControllerProvider).value;
});
