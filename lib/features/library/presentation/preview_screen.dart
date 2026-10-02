import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/clipboard/note_copier.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/services/content_share_ui.dart';
import '../application/browse_filtering.dart';
import '../application/library_providers.dart';
import '../domain/library_entry.dart';
import 'browse_screen.dart' show confirmDelete;
import 'widgets/video_preview.dart';

/// Previews a media/other file with support for swiping left/right between
/// elements in the same directory, selecting media items, and persistent
/// selection when navigating back to the browse list.
class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({required this.path, this.paths, super.key});

  final String path;

  /// When set (e.g. from search results), the swipe gallery is limited to
  /// these paths instead of the siblings of [path] in its folder.
  final List<String>? paths;

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  late PageController _pageController;
  late String _currentPath;
  int _currentIndex = 0;
  bool _initialSynced = false;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.path;

    final parent = p.dirname(widget.path);
    final cached = ref.read(directoryProvider(parent)).value;
    final given = widget.paths;
    if (given != null) {
      final idx = given.indexWhere((e) => p.equals(e, widget.path));
      if (idx != -1) {
        _currentIndex = idx;
        _initialSynced = true;
      }
    } else if (cached != null) {
      final sort = ref.read(browseSortProvider);
      final filter = ref.read(browseFilterProvider);
      final sorted = sortEntries(cached, sort);
      final list = (filter != null
          ? sorted.where((e) => e.kind == filter).toList()
          : null);
      final candidates =
          (list != null && list.any((e) => p.equals(e.path, widget.path)))
              ? list
              : sorted
                  .where((e) => !e.isFolder && !e.isNote && !e.isTable)
                  .toList();
      final idx = candidates.indexWhere((e) => p.equals(e.path, widget.path));
      if (idx != -1) {
        _currentIndex = idx;
        _initialSynced = true;
      }
    }

    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleSelect(String path) {
    final current = ref.read(selectedEntriesProvider);
    final next = Set<String>.from(current);
    if (!next.remove(path)) {
      next.add(path);
    }
    ref.read(selectedEntriesProvider.notifier).state = next;
  }

  /// Opens [path] with the system handler. No shell is involved: a file name
  /// such as `a&calc.exe` must never be interpreted as a command.
  Future<void> _openExternally(String path) async {
    try {
      await launchUrl(Uri.file(path), mode: LaunchMode.externalApplication);
    } catch (_) {
      // best effort
    }
  }

  Future<void> _shareImage(
      BuildContext context, AppStrings strings, String path) async {
    await shareWithFeedback(context, strings, text: null, mediaPaths: [path]);
  }

  Future<void> _copyImage(
      BuildContext context, AppStrings strings, String path) async {
    try {
      final files = await copyNoteToClipboard('', imagePaths: [path]);
      if (!context.mounted) return;
      _snack(
        context,
        files > 0 ? strings.copiedWithFiles(files) : strings.copyFailed,
      );
    } catch (_) {
      if (!context.mounted) return;
      _snack(context, strings.copyFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final parent = p.dirname(widget.path);
    final listing = ref.watch(directoryProvider(parent));
    final controller = ref.read(libraryControllerProvider);
    final sort = ref.watch(browseSortProvider);
    final filter = ref.watch(browseFilterProvider);

    final rawEntries = listing.value ?? const [];
    final sorted = sortEntries(rawEntries, sort);
    final filtered = filter != null
        ? sorted.where((e) => e.kind == filter).toList()
        : sorted.where((e) => !e.isFolder && !e.isNote && !e.isTable).toList();

    final List<LibraryEntry> entries;
    final given = widget.paths;
    if (given != null && given.isNotEmpty) {
      final index = ref.watch(libraryIndexProvider).value;
      final byPath = {
        for (final e in index ?? const <LibraryEntry>[]) p.normalize(e.path): e,
      };
      entries = [
        for (final path in given)
          if (index == null ||
              index.isEmpty ||
              byPath[p.normalize(path)] != null)
            byPath[p.normalize(path)] ??
                LibraryEntry(
                  path: path,
                  name: p.basename(path),
                  kind: kindForFile(p.basename(path)),
                  size: 0,
                  modified: DateTime.now(),
                ),
      ];
    } else if (filtered.isNotEmpty &&
        filtered.any((e) => p.equals(e.path, _currentPath))) {
      entries = filtered;
    } else if (sorted.isNotEmpty &&
        sorted.any((e) => p.equals(e.path, _currentPath))) {
      entries =
          sorted.where((e) => !e.isFolder && !e.isNote && !e.isTable).toList();
    } else {
      entries = [
        LibraryEntry(
          path: widget.path,
          name: p.basename(widget.path),
          kind: kindForFile(p.basename(widget.path)),
          size: 0,
          modified: DateTime.now(),
        ),
      ];
    }

    if (!_initialSynced && entries.isNotEmpty) {
      final idx = entries.indexWhere((e) => p.equals(e.path, _currentPath));
      if (idx != -1 && idx != _currentIndex) {
        _currentIndex = idx;
        _initialSynced = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(idx);
          }
        });
      } else if (idx != -1) {
        _initialSynced = true;
      }
    }

    final currentEntry =
        entries.firstWhereOrNull((e) => p.equals(e.path, _currentPath));
    final kind = currentEntry?.kind ?? kindForFile(p.basename(_currentPath));
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final currentParent = p.dirname(_currentPath);

    Future<void> toggleFavorite(String path, bool current) async {
      try {
        await controller.setFavorite(path, !current,
            parentDir: p.dirname(path));
      } catch (_) {
        if (!context.mounted) return;
        _snack(context, strings.genericError);
      }
    }

    final selectedSet = ref.watch(selectedEntriesProvider);
    final theme = Theme.of(context);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              _currentIndex > 0) {
            _pageController.previousPage(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              _currentIndex < entries.length - 1) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.basename(_currentPath),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (entries.length > 1)
                Text(
                  '${_currentIndex + 1} / ${entries.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          actions: [
            if (kind == EntryKind.image || kind == EntryKind.video)
              IconButton(
                tooltip: strings.copy,
                icon: const Icon(Icons.copy_outlined),
                onPressed: () => _copyImage(context, strings, _currentPath),
              ),
            IconButton(
              tooltip: kind == EntryKind.image ? strings.share : strings.open,
              icon: Icon(
                kind == EntryKind.image ? Icons.ios_share : Icons.open_in_new,
              ),
              onPressed: kind == EntryKind.image
                  ? () => _shareImage(context, strings, _currentPath)
                  : () => _openExternally(_currentPath),
            ),
            IconButton(
              tooltip: strings.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirmDelete(context, strings);
                if (ok != true) return;
                final pathToDelete = _currentPath;
                try {
                  await controller.moveToTrash(pathToDelete,
                      parentDir: currentParent);
                  final curSel = ref.read(selectedEntriesProvider);
                  if (curSel.contains(pathToDelete)) {
                    final next = Set<String>.from(curSel)..remove(pathToDelete);
                    ref.read(selectedEntriesProvider.notifier).state = next;
                  }
                } catch (_) {
                  if (!context.mounted) return;
                  _snack(context, strings.genericError);
                  return;
                }
                if (!context.mounted) return;
                if (entries.length <= 1) {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                } else {
                  final nextIndex = (_currentIndex >= entries.length - 1)
                      ? _currentIndex - 1
                      : _currentIndex;
                  _pageController.jumpToPage(nextIndex);
                }
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              physics: _isZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: entries.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _currentPath = entries[index].path;
                  _isZoomed = false;
                });
              },
              itemBuilder: (context, index) {
                final entry = entries[index];
                final entryKind = entry.kind;
                final isSelected = selectedSet.contains(entry.path);
                final entryFavorite = entry.isFavorite;

                return Stack(
                  children: [
                    Center(
                      child: switch (entryKind) {
                        EntryKind.image
                            when canRenderThumbnail(p.basename(entry.path)) =>
                          _ImagePreview(
                            path: entry.path,
                            errorLabel: strings.genericError,
                            onLongPress: isMobile
                                ? () {
                                    HapticFeedback.selectionClick();
                                    _toggleSelect(entry.path);
                                  }
                                : null,
                            onDoubleTap: isMobile
                                ? () {
                                    HapticFeedback.lightImpact();
                                    toggleFavorite(entry.path, entryFavorite);
                                  }
                                : null,
                            onZoomChanged: (zoomed) {
                              if (_isZoomed != zoomed) {
                                setState(() => _isZoomed = zoomed);
                              }
                            },
                          ),
                        EntryKind.image => _Info(
                            icon: Icons.image_outlined,
                            text: p.basename(entry.path),
                            actionIcon: Icons.ios_share,
                            actionLabel: strings.share,
                            onAction: () =>
                                _shareImage(context, strings, entry.path),
                          ),
                        EntryKind.video => VideoPreview(
                            key: ValueKey(entry.path),
                            path: entry.path,
                          ),
                        _ => _Info(
                            icon: Icons.insert_drive_file_outlined,
                            text: p.basename(entry.path),
                            actionIcon: Icons.open_in_new,
                            actionLabel: strings.open,
                            onAction: () => _openExternally(entry.path),
                          ),
                      },
                    ),
                    PositionedDirectional(
                      top: 16,
                      end: 16,
                      child: SafeArea(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _OverlayButton(
                              tooltip: entryFavorite
                                  ? strings.removeFromFavorites
                                  : strings.addToFavorites,
                              active: entryFavorite,
                              activeColor: Colors.amber.shade700,
                              icon: entryFavorite
                                  ? Icons.star
                                  : Icons.star_border,
                              onTap: () =>
                                  toggleFavorite(entry.path, entryFavorite),
                            ),
                            const SizedBox(width: 8),
                            _OverlayButton(
                              tooltip: isSelected
                                  ? strings.deselectAction
                                  : strings.selectAction,
                              active: isSelected,
                              activeColor: theme.colorScheme.primary,
                              icon: isSelected
                                  ? Icons.check
                                  : Icons.circle_outlined,
                              onTap: () => _toggleSelect(entry.path),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (entries.length > 1 && !isMobile) ...[
              if (_currentIndex > 0)
                PositionedDirectional(
                  start: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton.filledTonal(
                      tooltip: strings.previous,
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                    ),
                  ),
                ),
              if (_currentIndex < entries.length - 1)
                PositionedDirectional(
                  end: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton.filledTonal(
                      tooltip: strings.next,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                    ),
                  ),
                ),
            ],
            if (entries.length > 1)
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: IgnorePointer(
                    child: _PageDots(
                      count: entries.length,
                      current: _currentIndex,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.tooltip,
    required this.active,
    required this.activeColor,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final bool active;
  final Color activeColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? activeColor : Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Page dots for the gallery; shows a sliding window when there are many.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  static const _window = 9;

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final shown = count < _window ? count : _window;
    final start = (current - shown ~/ 2).clamp(0, count - shown);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = start; i < start + shown; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == current ? 16 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == current
                        ? scheme.primary
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A fullscreen-style dialog that shows an image using [_ImagePreview] (with
/// pinch-to-zoom) and exposes a copy button in the header.
class ImageViewerDialog extends StatelessWidget {
  const ImageViewerDialog({
    required this.path,
    required this.onCopy,
    super.key,
  });

  final String path;
  final VoidCallback onCopy;

  static Future<void> show(
    BuildContext context, {
    required String path,
    required VoidCallback onCopy,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ImageViewerDialog(path: path, onCopy: onCopy),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filename = p.basename(path);
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(filename, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copier',
              onPressed: () {
                Navigator.of(context).pop();
                onCopy();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: _ImagePreview(
            path: path,
            errorLabel: filename,
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatefulWidget {
  const _ImagePreview({
    required this.path,
    required this.errorLabel,
    this.onZoomChanged,
    this.onDoubleTap,
    this.onLongPress,
  });

  final String path;
  final String errorLabel;
  final ValueChanged<bool>? onZoomChanged;

  /// Overrides the default double-tap zoom (used for "star" on mobile).
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_handleTransform);
  }

  @override
  void dispose() {
    _transformController.removeListener(_handleTransform);
    _transformController.dispose();
    super.dispose();
  }

  void _handleTransform() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    widget.onZoomChanged?.call(scale > 1.05);
  }

  void _handleDoubleTap() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if (scale > 1.05) {
      _transformController.value = Matrix4.identity();
    } else {
      _transformController.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.sizeOf(context);
        final isMobile = screen.width < 700;
        final maxWidth = isMobile
            ? constraints.maxWidth
            : (constraints.maxWidth * 0.92).clamp(640.0, 1280.0);
        final maxHeight = isMobile
            ? constraints.maxHeight
            : (constraints.maxHeight * 0.9).clamp(420.0, 900.0);

        return GestureDetector(
          onDoubleTap: widget.onDoubleTap ?? _handleDoubleTap,
          onLongPress: widget.onLongPress,
          child: InteractiveViewer(
            transformationController: _transformController,
            maxScale: 5,
            constrained: false,
            child: SizedBox(
              width: maxWidth,
              height: maxHeight,
              child: Image.file(
                File(widget.path),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _Info(
                  icon: Icons.broken_image_outlined,
                  text: widget.errorLabel,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _Info extends StatelessWidget {
  const _Info({
    required this.icon,
    required this.text,
    this.actionIcon,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final IconData? actionIcon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon ?? Icons.open_in_new),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
