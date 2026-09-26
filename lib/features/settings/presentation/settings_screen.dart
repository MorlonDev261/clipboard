import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/workspace_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _changeWorkspace(WidgetRef ref) async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) {
      await ref.read(workspaceControllerProvider.notifier).setRoot(dir);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final root = ref.watch(workspaceRootProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(strings.workspaceFolder),
            subtitle: Text(root ?? '—'),
          ),
          ListTile(
            leading: const Icon(Icons.drive_folder_upload_outlined),
            title: Text(strings.changeWorkspace),
            onTap: () => _changeWorkspace(ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(strings.appName),
            subtitle: const Text('Clipboard — MVP'),
          ),
        ],
      ),
    );
  }
}
