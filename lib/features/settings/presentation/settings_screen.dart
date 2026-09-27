import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/picker/app_file_picker.dart';
import '../../../core/picker/pick_mode.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../core/providers/workspace_providers.dart';
import '../../../shared/enums/enums.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _changeWorkspace(BuildContext context, WidgetRef ref) async {
    final strings = ref.read(appStringsProvider);
    final dirs = await AppFilePicker.pick(
      context,
      mode: PickMode.directory,
      title: strings.changeWorkspace,
    );
    if (dirs.isNotEmpty) {
      await ref.read(workspaceControllerProvider.notifier).setRoot(dirs.first);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final root = ref.watch(workspaceRootProvider);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        children: [
          _SectionHeader(strings.workspaceFolder),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(strings.workspaceFolder),
            subtitle: Text(root ?? '—'),
          ),
          ListTile(
            leading: const Icon(Icons.drive_folder_upload_outlined),
            title: Text(strings.changeWorkspace),
            onTap: () => _changeWorkspace(context, ref),
          ),
          const Divider(),
          _SectionHeader(strings.appearance),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(strings.theme),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              onChanged: (m) => m == null ? null : controller.setThemeMode(m),
              items: [
                DropdownMenuItem(
                    value: ThemeMode.system, child: Text(strings.themeSystem)),
                DropdownMenuItem(
                    value: ThemeMode.light, child: Text(strings.themeLight)),
                DropdownMenuItem(
                    value: ThemeMode.dark, child: Text(strings.themeDark)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.grid_view_outlined),
            title: Text(strings.defaultView),
            trailing: DropdownButton<ViewMode>(
              value: settings.viewMode,
              onChanged: (v) => v == null ? null : controller.setViewMode(v),
              items: [
                DropdownMenuItem(
                    value: ViewMode.grid, child: Text(strings.viewGrid)),
                DropdownMenuItem(
                    value: ViewMode.list, child: Text(strings.viewList)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(strings.language),
            trailing: DropdownButton<String>(
              value: settings.languageCode,
              onChanged: (c) => c == null ? null : controller.setLanguage(c),
              items: [
                DropdownMenuItem(value: 'fr', child: Text(strings.french)),
                DropdownMenuItem(value: 'en', child: Text(strings.english)),
              ],
            ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
