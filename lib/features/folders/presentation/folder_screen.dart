import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/enums/enums.dart';
import '../../../shared/providers/ui_providers.dart';
import '../../assets/application/assets_providers.dart';
import '../application/folders_providers.dart';
import '../domain/folder.dart';

/// Displays a folder: its sub-folders, its content and the folder actions.
class FolderScreen extends ConsumerWidget {
  const FolderScreen({required this.folderId, super.key});

  final String folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final folderAsync = ref.watch(folderProvider(folderId));
    final viewMode = ref.watch(viewModeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => _goBack(context)),
        title: folderAsync.maybeWhen(
          data: (f) => Text(f?.name ?? strings.genericError),
          orElse: () => Text(strings.appName),
        ),
        actions: [
          IconButton(
            tooltip: viewMode == ViewMode.grid ? strings.contents : strings.contents,
            icon: Icon(viewMode == ViewMode.grid
                ? Icons.view_list_outlined
                : Icons.grid_view_outlined),
            onPressed: () => ref.read(viewModeProvider.notifier).state =
                viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid,
          ),
          folderAsync.maybeWhen(
            data: (f) => f == null
                ? const SizedBox.shrink()
                : _FolderMenu(folder: f),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateFolderDialog(context, ref),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: Text(strings.newFolder),
      ),
      body: folderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(strings.genericError)),
        data: (folder) {
          if (folder == null) {
            return Center(child: Text(strings.genericError));
          }
          return _FolderBody(folder: folder);
        },
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _showCreateFolderDialog(
      BuildContext context, WidgetRef ref) async {
    final strings = ref.read(appStringsProvider);
    final name = await _promptForName(
      context,
      title: strings.newFolderTitle,
      label: strings.folderNameLabel,
      confirmLabel: strings.create,
      cancelLabel: strings.cancel,
    );
    if (name == null) return;
    try {
      await ref
          .read(foldersControllerProvider)
          .createFolder(name: name, parentId: folderId);
      if (context.mounted) {
        _showSnack(context, strings.folderCreated(name));
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, strings.genericError);
    }
  }
}

class _FolderBody extends ConsumerWidget {
  const _FolderBody({required this.folder});

  final Folder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final children = ref.watch(childFoldersProvider(folder.id));
    final assets = ref.watch(folderAssetsProvider(folder.id));
    final viewMode = ref.watch(viewModeProvider);

    return ListView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      children: [
        _Breadcrumb(folder: folder),
        const SizedBox(height: 12),
        Text(strings.subfolders,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        children.when(
          loading: () =>
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
          error: (e, _) => Text(strings.genericError),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(strings.noSubfolders,
                      style: Theme.of(context).textTheme.bodyMedium),
                )
              : Column(
                  children: [
                    for (final child in list)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(child.name),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go('/folder/${child.id}'),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        Text(strings.contents,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        assets.when(
          loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
          error: (e, _) => Text(strings.genericError),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.inbox_outlined,
                title: strings.emptyFolderTitle,
                message: strings.emptyFolderMessage,
              );
            }
            // Media/text rendering arrives in a later milestone; for now show
            // a simple typed list so the wiring is verifiable.
            if (viewMode == ViewMode.list) {
              return Column(
                children: [
                  for (final a in list)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(a.title ?? a.name),
                      ),
                    ),
                ],
              );
            }
            return GridView.count(
              crossAxisCount:
                  MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint
                      ? 4
                      : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (final a in list)
                  Card(
                    child: Center(child: Text(a.title ?? a.name)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.folder});

  final Folder folder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.folder, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            folder.name,
            style: theme.textTheme.titleLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _FolderMenu extends ConsumerWidget {
  const _FolderMenu({required this.folder});

  final Folder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return PopupMenuButton<String>(
      onSelected: (value) => _onSelected(context, ref, value),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'rename', child: Text(strings.rename)),
        if (!folder.isRoot)
          PopupMenuItem(value: 'delete', child: Text(strings.delete)),
      ],
    );
  }

  Future<void> _onSelected(
      BuildContext context, WidgetRef ref, String value) async {
    final strings = ref.read(appStringsProvider);
    final controller = ref.read(foldersControllerProvider);
    switch (value) {
      case 'rename':
        final name = await _promptForName(
          context,
          title: strings.renameFolderTitle,
          label: strings.folderNameLabel,
          confirmLabel: strings.save,
          cancelLabel: strings.cancel,
          initialValue: folder.name,
        );
        if (name == null) return;
        await controller.renameFolder(folder, name);
      case 'delete':
        final confirmed = await _confirmDelete(context, strings);
        if (confirmed != true) return;
        try {
          await controller.deleteFolder(folder);
          if (context.mounted) {
            _showSnack(context, strings.folderDeleted(folder.name));
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          }
        } on StateError {
          if (context.mounted) _showSnack(context, strings.mainCannotBeDeleted);
        }
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, AppStrings strings) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteFolderTitle),
        content: Text(strings.deleteFolderMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
  }
}

/// Shared text-input dialog used for folder creation and renaming.
Future<String?> _promptForName(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  required String cancelLabel,
  String? initialValue,
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}
