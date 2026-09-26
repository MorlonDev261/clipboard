import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../../folders/application/folders_providers.dart';
import '../application/home_providers.dart';

/// Landing screen: quick stats, the "Main" entry point and recent folders.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final rootFolder = ref.watch(rootFolderProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.appName)),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppConstants.maxContentWidth),
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardStatsProvider);
              ref.invalidate(rootFolderProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              children: [
                _SearchField(
                  hint: strings.searchHint,
                  onTap: () => context.go('/search'),
                ),
                const SizedBox(height: 24),
                Text(strings.quickStats,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                const _StatsGrid(),
                const SizedBox(height: 24),
                rootFolder.when(
                  loading: () => const Center(
                      child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  )),
                  error: (e, _) => Text(strings.genericError),
                  data: (folder) => FilledButton.icon(
                    onPressed: () => context.go('/folder/${folder.id}'),
                    icon: const Icon(Icons.folder_open),
                    label: Text(strings.openMain),
                  ),
                ),
                const SizedBox(height: 24),
                Text(strings.recentFolders,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                rootFolder.maybeWhen(
                  data: (folder) => _RecentFolders(parentId: folder.id),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
      ),
    );
  }
}

class _StatsGrid extends ConsumerWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= AppConstants.desktopBreakpoint ? 4 : 2;

    final data = stats.valueOrNull;
    final items = <(_StatKind, IconData, String, int?)>[
      (_StatKind.images, Icons.image_outlined, strings.images, data?.images),
      (_StatKind.videos, Icons.videocam_outlined, strings.videos, data?.videos),
      (_StatKind.texts, Icons.notes_outlined, strings.texts, data?.texts),
      (_StatKind.posts, Icons.dynamic_feed_outlined, strings.posts, data?.posts),
    ];

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        for (final (_, icon, label, value) in items)
          _StatCard(icon: icon, label: label, value: value),
      ],
    );
  }
}

enum _StatKind { images, videos, texts, posts }

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value?.toString() ?? '—',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _RecentFolders extends ConsumerWidget {
  const _RecentFolders({required this.parentId});

  final String parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final folders = ref.watch(childFoldersProvider(parentId));

    return folders.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text(strings.genericError),
      data: (list) {
        if (list.isEmpty) {
          return Text(
            strings.noSubfolders,
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        return Column(
          children: [
            for (final folder in list.take(6))
              Card(
                child: ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(folder.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/folder/${folder.id}'),
                ),
              ),
          ],
        );
      },
    );
  }
}
