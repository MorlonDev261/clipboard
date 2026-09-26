import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_constants.dart';
import '../../../app/nav.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/workspace_providers.dart';
import '../../library/application/library_providers.dart';
import '../../library/domain/library_entry.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _pickWorkspace(WidgetRef ref) async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) {
      await ref.read(workspaceControllerProvider.notifier).setRoot(dir);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final workspace = ref.watch(workspaceControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.appName)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppConstants.maxContentWidth),
          child: workspace.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(strings.genericError)),
            data: (root) => root == null
                ? _ChooseWorkspace(onPick: () => _pickWorkspace(ref))
                : _Dashboard(root: root),
          ),
        ),
      ),
    );
  }
}

class _ChooseWorkspace extends ConsumerWidget {
  const _ChooseWorkspace({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_special_outlined,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
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
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.root});

  final String root;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final listing = ref.watch(directoryProvider(root));

    return ListView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(strings.workspaceFolder),
            subtitle: Text(root),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.push(browseRoute(root)),
          icon: const Icon(Icons.grid_view_rounded),
          label: Text(strings.openLibrary),
        ),
        const SizedBox(height: 24),
        Text(strings.contents, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        listing.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(strings.genericError),
          data: (entries) => _StatsRow(entries: entries),
        ),
      ],
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.entries});

  final List<LibraryEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    int count(bool Function(LibraryEntry) test) => entries.where(test).length;
    final items = <(IconData, String, int)>[
      (Icons.folder_outlined, strings.folders, count((e) => e.isFolder)),
      (Icons.image_outlined, strings.images, count((e) => e.isImage)),
      (Icons.videocam_outlined, strings.videos, count((e) => e.isVideo)),
      (Icons.notes_outlined, strings.notes, count((e) => e.isNote)),
    ];
    final columns =
        MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint ? 4 : 2;
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        for (final (icon, label, value) in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 8),
                  Text('$value',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
