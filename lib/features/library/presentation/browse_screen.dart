import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:path/path.dart' as p;

import '../../../app/constants/app_constants.dart';

import '../../../app/nav.dart';

import '../../../core/l10n/app_strings.dart';

import '../../../core/picker/app_file_picker.dart';

import '../../../core/picker/pick_mode.dart';

import '../../../core/providers/settings_providers.dart';

import '../../../core/providers/workspace_providers.dart';

import '../../../core/widgets/empty_state.dart';

import '../../../shared/enums/enums.dart';

import '../application/browse_filtering.dart';

import '../application/library_providers.dart';

import '../domain/library_entry.dart';

/// Browses a real directory on disk: subfolders + files, with breadcrumb,

/// sort, filters, create, import, drag & drop and per-entry actions.

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({required this.dirPath, this.showBack = true, super.key});

  final String dirPath;

  /// When false (used as the Home tab's root view), no back button is shown

  /// and the title falls back to the app name.

  final bool showBack;

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  bool _dragging = false;

  String get _dir => widget.dirPath;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    final root = ref.watch(workspaceRootProvider);

    final isRoot = root != null && p.equals(root, _dir);

    final viewMode = ref.watch(settingsProvider).viewMode;

    final sort = ref.watch(browseSortProvider);

    final filter = ref.watch(browseFilterProvider);

    // With a kind filter active we need the recursive listing so that, for any

    // match nested deep down, entriesForFilter can surface the direct

    // sub-folder that leads to it (never the deep item itself), ordered by how

    // close the match is. The unfiltered "all" view stays a plain,

    // direct-children listing for normal browsing.

    final listing = filter == null
        ? ref.watch(directoryProvider(_dir))
        : ref.watch(dirRecursiveProvider(_dir));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBack,
        leading: widget.showBack
            ? BackButton(onPressed: () => _back(context))
            : null,
        title: widget.showBack
            ? Text(isRoot ? strings.library : p.basename(_dir))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icon/icon.png',
                    width: 28,
                    height: 28,
                    filterQuality: FilterQuality.medium,
                  ),
                  const SizedBox(width: 8),
                  Text(strings.appName),
                ],
              ),
        actions: [
          IconButton(
            tooltip: strings.search,
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          _SortMenu(),
          IconButton(
            tooltip: strings.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(directoryProvider(_dir));

              ref.invalidate(dirStatsProvider(_dir));
            },
          ),
          IconButton(
            tooltip: strings.contents,
            icon: Icon(viewMode == ViewMode.grid
                ? Icons.view_list_outlined
                : Icons.grid_view_outlined),
            onPressed: () => ref
                .read(settingsControllerProvider.notifier)
                .setViewMode(
                    viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.add),
        label: Text(strings.add),
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: (detail) async {
          setState(() => _dragging = false);

          final paths = detail.files
              .map((f) => f.path)
              .where((path) => path.isNotEmpty)
              .toList();

          if (paths.isNotEmpty) {
            await _import(paths);
          }
        },
        child: Stack(
          children: [
            Column(
              children: [
                if (root != null) _Breadcrumb(root: root, dir: _dir),
                _StatsCards(dir: _dir),
                _FilterBar(),
                Expanded(
                  child: listing.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text(strings.genericError)),
                    data: (entries) {
                      final visible = filter == null
                          ? sortEntries(entries, sort)
                          : entriesForFilter(entries, _dir, filter);

                      if (visible.isEmpty) {
                        return _EmptyBrowse(dropping: _dragging);
                      }

                      return _EntryView(
                          dir: _dir, entries: visible, viewMode: viewMode);
                    },
                  ),
                ),
              ],
            ),
            if (_dragging) _DropOverlay(label: strings.dropToImport),
          ],
        ),
      ),
    );
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _showAddSheet(BuildContext context) async {
    final strings = ref.read(appStringsProvider);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(strings.newFolder),
              onTap: () {
                Navigator.pop(sheetContext);

                _createFolder();
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: Text(strings.newNote),
              onTap: () {
                Navigator.pop(sheetContext);

                context.push(newNoteRoute(_dir));
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(strings.importFiles),
              onTap: () {
                Navigator.pop(sheetContext);

                _pickAndImport();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createFolder() async {
    final strings = ref.read(appStringsProvider);

    final name = await promptForName(
      context,
      title: strings.newFolderTitle,
      label: strings.folderNameLabel,
      confirmLabel: strings.create,
      cancelLabel: strings.cancel,
    );

    if (name == null || name.trim().isEmpty) return;

    try {
      await ref.read(libraryControllerProvider).createFolder(_dir, name.trim());

      if (mounted) _snack(strings.folderCreated(name.trim()));
    } catch (_) {
      if (mounted) _snack(strings.genericError);
    }
  }

  Future<void> _pickAndImport() async {
    final strings = ref.read(appStringsProvider);

    final paths = await AppFilePicker.pick(
      context,
      mode: PickMode.files,
      title: strings.importFiles,
    );

    if (paths.isNotEmpty) {
      await _import(paths);
    }
  }

  Future<void> _import(List<String> paths) async {
    final strings = ref.read(appStringsProvider);

    try {
      final failed =
          await ref.read(libraryControllerProvider).importPaths(_dir, paths);

      if (mounted) {
        _snack(
            strings.importReport(paths.length - failed.length, failed.length));
      }
    } catch (_) {
      if (mounted) _snack(strings.genericError);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SortMenu extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);

    String label(SortOption o) => switch (o) {
          SortOption.nameAsc => strings.sortNameAsc,
          SortOption.nameDesc => strings.sortNameDesc,
          SortOption.newest => strings.sortNewest,
          SortOption.oldest => strings.sortOldest,
          SortOption.sizeAsc => strings.sortSizeAsc,
          SortOption.sizeDesc => strings.sortSizeDesc,
        };

    return PopupMenuButton<SortOption>(
      tooltip: strings.sortBy,
      icon: const Icon(Icons.sort),
      onSelected: (o) => ref.read(browseSortProvider.notifier).state = o,
      itemBuilder: (context) => [
        for (final o in SortOption.values)
          PopupMenuItem(value: o, child: Text(label(o))),
      ],
    );
  }
}

/// Dynamic stat cards for the current folder (recursive: folder + subfolders).

class _StatsCards extends ConsumerWidget {
  const _StatsCards({required this.dir});

  final String dir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);

    final stats = ref.watch(dirStatsProvider(dir)).value;

    final items = <(IconData, String, int?)>[
      (Icons.folder_outlined, strings.folders, stats?.folders),
      (Icons.image_outlined, strings.images, stats?.images),
      (Icons.videocam_outlined, strings.videos, stats?.videos),
      (Icons.notes_outlined, strings.notes, stats?.notes),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          for (final (icon, label, value) in items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Column(
                      children: [
                        Icon(icon,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 4),
                        Text(
                          value?.toString() ?? '—',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);

    final current = ref.watch(browseFilterProvider);

    final options = <(EntryKind?, String)>[
      (null, strings.all),
      (EntryKind.folder, strings.folders),
      (EntryKind.image, strings.images),
      (EntryKind.video, strings.videos),
      (EntryKind.note, strings.notes),
    ];

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final (kind, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: current == kind,
                onSelected: (_) =>
                    ref.read(browseFilterProvider.notifier).state = kind,
              ),
            ),
        ],
      ),
    );
  }
}

class _Breadcrumb extends ConsumerWidget {
  const _Breadcrumb({required this.root, required this.dir});

  final String root;

  final String dir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);

    // Build the chain from root down to the current directory.

    final crumbs = <(String, String)>[(strings.library, root)];

    final rel = p.relative(dir, from: root);

    if (rel != '.') {
      var acc = root;

      for (final seg in p.split(rel)) {
        acc = p.join(acc, seg);

        crumbs.add((seg, acc));
      }
    }

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: crumbs.length,
        itemBuilder: (context, i) {
          final (label, path) = crumbs[i];

          final isLast = i == crumbs.length - 1;

          return Row(
            children: [
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.chevron_right, size: 18),
                ),
              TextButton(
                onPressed: isLast ? null : () => context.go(browseRoute(path)),
                child: Text(label),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EntryView extends ConsumerWidget {
  const _EntryView({
    required this.dir,
    required this.entries,
    required this.viewMode,
  });

  final String dir;

  final List<LibraryEntry> entries;

  final ViewMode viewMode;

  void _open(BuildContext context, LibraryEntry e) {
    if (e.isFolder) {
      context.push(browseRoute(e.path));
    } else if (e.isNote) {
      context.push(noteRoute(e.path));
    } else {
      context.push(previewRoute(e.path));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (viewMode == ViewMode.list) {
      return ListView.builder(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final e = entries[i];

          return Card(
            child: ListTile(
              leading: _EntryThumb(entry: e, size: 40),
              title: Text(e.displayName),
              subtitle: e.isFolder ? _tagsLine(e) : _fileSubtitle(e),
              trailing: _EntryMenu(dir: dir, entry: e),
              onTap: () => _open(context, e),
            ),
          );
        },
      );
    }

    final columns =
        MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint
            ? 4
            : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _open(context, e),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _EntryThumb(entry: e, fill: true)),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      if (e.isFavorite)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.star, size: 14),
                        ),
                      Expanded(
                        child: Text(
                          e.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      _EntryMenu(dir: dir, entry: e, dense: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget? _tagsLine(LibraryEntry e) =>
      e.tags.isEmpty ? null : Text('#${e.tags.join(' #')}');

  Widget _fileSubtitle(LibraryEntry e) {
    final kb = e.size / 1024;

    final size = kb < 1024
        ? '${kb.toStringAsFixed(0)} Ko'
        : '${(kb / 1024).toStringAsFixed(1)} Mo';

    final tags = e.tags.isEmpty ? '' : '  ·  #${e.tags.join(' #')}';

    return Text('$size$tags', maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

/// A thumbnail for an entry: real image preview for images, an icon otherwise.

class _EntryThumb extends StatelessWidget {
  const _EntryThumb({required this.entry, this.size, this.fill = false});

  final LibraryEntry entry;

  final double? size;

  final bool fill;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    if (entry.isImage && canRenderThumbnail(entry.name)) {
      final image = Image.file(
        File(entry.path),
        fit: BoxFit.cover,
        width: fill ? double.infinity : size,
        height: fill ? double.infinity : size,
        cacheWidth: fill ? 400 : 96,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.broken_image_outlined, color: color, size: size ?? 40),
      );

      if (fill) return image;

      return ClipRRect(borderRadius: BorderRadius.circular(6), child: image);
    }

    final icon = Icon(_iconFor(entry.kind),
        color: color, size: fill ? 40 : (size ?? 24));

    if (fill) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(child: icon),
      );
    }

    return icon;
  }
}

class _EntryMenu extends ConsumerWidget {
  const _EntryMenu(
      {required this.dir, required this.entry, this.dense = false});

  final String dir;

  final LibraryEntry entry;

  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);

    final controller = ref.read(libraryControllerProvider);

    return PopupMenuButton<String>(
      icon: dense ? const Icon(Icons.more_vert, size: 18) : null,
      onSelected: (value) async {
        switch (value) {
          case 'favorite':
            await controller.setFavorite(entry.path, !entry.isFavorite,
                parentDir: dir);

          case 'tags':
            final tags = await _promptTags(context, strings, entry.tags);

            if (tags != null) {
              await controller.setTags(entry.path, tags, parentDir: dir);
            }

          case 'rename':
            final name = await promptForName(
              context,
              title: strings.renameTitle,
              label: strings.nameLabel,
              confirmLabel: strings.save,
              cancelLabel: strings.cancel,
              initialValue: entry.displayName,
            );

            if (name != null && name.trim().isNotEmpty) {
              await controller.rename(entry.path, name.trim(), parentDir: dir);
            }

          case 'move':
            final dests = await AppFilePicker.pick(
              context,
              mode: PickMode.directory,
              title: strings.chooseDestination,
            );

            if (dests.isNotEmpty && !p.equals(dests.first, dir)) {
              await controller.move(entry.path, dests.first, parentDir: dir);
            }

          case 'duplicate':
            await controller.duplicate(entry.path, parentDir: dir);

          case 'delete':
            final ok = await confirmDelete(context, strings);

            if (ok == true) {
              await controller.moveToTrash(entry.path, parentDir: dir);
            }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'favorite',
          child: Text(entry.isFavorite
              ? strings.removeFromFavorites
              : strings.addToFavorites),
        ),
        PopupMenuItem(value: 'tags', child: Text(strings.editTags)),
        PopupMenuItem(value: 'rename', child: Text(strings.rename)),
        PopupMenuItem(value: 'move', child: Text(strings.move)),
        PopupMenuItem(value: 'duplicate', child: Text(strings.duplicate)),
        PopupMenuItem(value: 'delete', child: Text(strings.delete)),
      ],
    );
  }
}

class _EmptyBrowse extends ConsumerWidget {
  const _EmptyBrowse({required this.dropping});

  final bool dropping;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);

    return EmptyState(
      icon: dropping ? Icons.file_download_outlined : Icons.inbox_outlined,
      title: strings.emptyFolderTitle,
      message: dropping ? strings.dropToImport : strings.emptyFolderMessage,
    );
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return IgnorePointer(
      child: Container(
        color: color.withValues(alpha: 0.08),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.file_download_outlined, color: color),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(EntryKind kind) {
  switch (kind) {
    case EntryKind.folder:
      return Icons.folder_outlined;

    case EntryKind.note:
      return Icons.description_outlined;

    case EntryKind.image:
      return Icons.image_outlined;

    case EntryKind.video:
      return Icons.videocam_outlined;

    case EntryKind.other:
      return Icons.insert_drive_file_outlined;
  }
}

/// Shared text-input dialog (folder creation, rename).

Future<String?> promptForName(
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
    builder: (context) => AlertDialog(
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
    ),
  );
}

/// Comma-separated tag editor. Returns the parsed list, or null on cancel.

Future<List<String>?> _promptTags(
    BuildContext context, AppStrings strings, List<String> current) {
  final controller = TextEditingController(text: current.join(', '));

  return showDialog<List<String>>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(strings.editTags),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: strings.tags,
          hintText: strings.tagsHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () {
            final tags = controller.text
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();

            Navigator.pop(context, tags);
          },
          child: Text(strings.save),
        ),
      ],
    ),
  );
}

Future<bool?> confirmDelete(BuildContext context, AppStrings strings) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(strings.deleteTitle),
      content: Text(strings.deleteMessage),
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
