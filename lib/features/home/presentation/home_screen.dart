import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/picker/app_file_picker.dart';
import '../../../core/picker/pick_mode.dart';
import '../../../core/providers/workspace_providers.dart';
import '../../library/presentation/browse_screen.dart';

/// Home tab: shows the working folder directly (its contents + the Add button)
/// once a workspace is chosen, or the workspace picker otherwise.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _pickWorkspace(BuildContext context, WidgetRef ref) async {
    final strings = ref.read(appStringsProvider);
    final dirs = await AppFilePicker.pick(
      context,
      mode: PickMode.directory,
      title: strings.chooseWorkspace,
    );
    if (dirs.isNotEmpty) {
      await ref.read(workspaceControllerProvider.notifier).setRoot(dirs.first);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final workspace = ref.watch(workspaceControllerProvider);

    return workspace.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(strings.appName)),
        body: Center(child: Text(strings.genericError)),
      ),
      data: (root) {
        if (root == null) {
          return Scaffold(
            appBar: AppBar(title: Text(strings.appName)),
            body: _ChooseWorkspace(onPick: () => _pickWorkspace(context, ref)),
          );
        }
        // The working folder IS the home view: add/import/drag & drop happen
        // directly here, on the current (root) folder.
        return BrowseScreen(dirPath: root, showBack: false);
      },
    );
  }
}

class _ChooseWorkspace extends ConsumerWidget {
  const _ChooseWorkspace({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icon/icon.png',
              width: 160,
              height: 160,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(height: 24),
            Text(strings.chooseWorkspace,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(strings.workspaceIntro,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.drive_folder_upload_outlined),
              label: Text(strings.chooseWorkspace),
            ),
          ],
        ),
      ),
    );
  }
}
