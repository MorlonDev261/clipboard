import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../features/library/domain/library_entry.dart';
import '../l10n/app_strings.dart';
import 'pick_mode.dart';

/// Opens the in-app file browser as a full-screen route and returns the chosen
/// absolute paths (empty if cancelled). For [PickMode.directory] the list holds
/// the single chosen folder.
Future<List<String>> launchInAppBrowser(
  BuildContext context, {
  required PickMode mode,
  bool allowMultiple = true,
  String? title,
}) async {
  final result = await Navigator.of(context).push<List<String>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FileBrowserScreen(
        mode: mode,
        allowMultiple: allowMultiple,
        title: title,
      ),
    ),
  );
  return result ?? const [];
}

class _FileBrowserScreen extends ConsumerStatefulWidget {
  const _FileBrowserScreen({
    required this.mode,
    required this.allowMultiple,
    this.title,
  });

  final PickMode mode;
  final bool allowMultiple;
  final String? title;

  @override
  ConsumerState<_FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _Shortcut {
  const _Shortcut(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}

class _FileBrowserScreenState extends ConsumerState<_FileBrowserScreen> {
  Directory? _current;
  List<FileSystemEntity> _entries = const [];
  final Set<String> _selected = <String>{};
  var _shortcuts = <_Shortcut>[];
  bool _loading = true;
  bool _multi = false;
  String? _error;

  bool get _fileMode => widget.mode != PickMode.directory;

  @override
  void initState() {
    super.initState();
    _multi = _fileMode && widget.allowMultiple;
    _shortcuts = _buildShortcuts();
    _load(Directory(_initialDir()));
  }

  // --- Locations -------------------------------------------------------------

  String _env(String key) => Platform.environment[key] ?? '';

  String _initialDir() {
    if (Platform.isWindows) {
      final home = _env('USERPROFILE');
      if (home.isNotEmpty && Directory(home).existsSync()) return home;
      return 'C:\\';
    }
    if (Platform.isAndroid) {
      const internal = '/storage/emulated/0';
      if (Directory(internal).existsSync()) return internal;
      return '/';
    }
    final home = _env('HOME');
    if (home.isNotEmpty && Directory(home).existsSync()) return home;
    return '/';
  }

  List<_Shortcut> _buildShortcuts() {
    final strings = ref.read(appStringsProvider);
    final out = <_Shortcut>[];
    void add(String label, IconData icon, String path) {
      if (path.isNotEmpty && Directory(path).existsSync()) {
        out.add(_Shortcut(label, icon, path));
      }
    }

    if (Platform.isWindows) {
      final home = _env('USERPROFILE');
      add(strings.locationHome, Icons.home_outlined, home);
      add(strings.locationDesktop, Icons.desktop_windows_outlined,
          p.join(home, 'Desktop'));
      add(strings.locationDocuments, Icons.description_outlined,
          p.join(home, 'Documents'));
      add(strings.locationDownloads, Icons.download_outlined,
          p.join(home, 'Downloads'));
      for (var c = 'A'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++) {
        final letter = String.fromCharCode(c);
        add('$letter:', Icons.storage_outlined, '$letter:\\');
      }
    } else if (Platform.isAndroid) {
      const internal = '/storage/emulated/0';
      add(strings.locationHome, Icons.smartphone_outlined, internal);
      add(strings.locationDownloads, Icons.download_outlined,
          '$internal/Download');
      add('DCIM', Icons.photo_camera_outlined, '$internal/DCIM');
      add(strings.images, Icons.image_outlined, '$internal/Pictures');
    } else {
      final home = _env('HOME');
      add(strings.locationHome, Icons.home_outlined, home);
      add(strings.locationDesktop, Icons.desktop_mac_outlined,
          p.join(home, 'Desktop'));
      add(strings.locationDocuments, Icons.description_outlined,
          p.join(home, 'Documents'));
      add(strings.locationDownloads, Icons.download_outlined,
          p.join(home, 'Downloads'));
    }
    return out;
  }

  // --- Loading ---------------------------------------------------------------

  Future<void> _load(Directory dir) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final items = <FileSystemEntity>[];
    try {
      await for (final ent in dir.list(followLinks: false)) {
        final name = p.basename(ent.path);
        if (name.startsWith('.')) continue; // hidden
        if (ent is Directory) {
          items.add(ent);
        } else if (ent is File) {
          if (widget.mode == PickMode.directory) continue;
          if (widget.mode == PickMode.imageFiles &&
              kindForFile(name) != EntryKind.image) {
            continue;
          }
          items.add(ent);
        }
      }
    } catch (_) {
      final strings = ref.read(appStringsProvider);
      if (mounted) {
        setState(() {
          _current = dir;
          _loading = false;
          _error = strings.folderAccessError;
          _entries = const [];
        });
      }
      return;
    }
    items.sort((a, b) {
      final ad = a is Directory;
      final bd = b is Directory;
      if (ad != bd) return ad ? -1 : 1;
      return p
          .basename(a.path)
          .toLowerCase()
          .compareTo(p.basename(b.path).toLowerCase());
    });
    if (!mounted) return;
    setState(() {
      _current = dir;
      _entries = items;
      _loading = false;
    });
  }

  void _goUp() {
    final cur = _current;
    if (cur == null) return;
    final parent = cur.parent;
    if (p.equals(parent.path, cur.path)) return; // already at a root
    _load(parent);
  }

  // --- Selection / confirmation ---------------------------------------------

  void _onFileTap(File file) {
    if (!_multi) {
      Navigator.of(context).pop(<String>[file.path]);
      return;
    }
    setState(() {
      if (!_selected.add(file.path)) _selected.remove(file.path);
    });
  }

  void _confirmFiles() => Navigator.of(context).pop(_selected.toList());

  void _confirmDirectory() {
    final cur = _current;
    if (cur != null) Navigator.of(context).pop(<String>[cur.path]);
  }

  String _confirmLabel(AppStrings s) =>
      widget.mode == PickMode.imageFiles ? s.selectAction : s.importAction;

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final title = widget.title ??
        (widget.mode == PickMode.directory
            ? strings.chooseDestination
            : widget.mode == PickMode.imageFiles
                ? strings.selectImagesTitle
                : strings.selectFilesTitle);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: strings.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title),
      ),
      body: Column(
        children: [
          _ShortcutsBar(
            shortcuts: _shortcuts,
            currentPath: _current?.path,
            onTap: (path) => _load(Directory(path)),
          ),
          _PathBar(
            path: _current?.path ?? '',
            canGoUp: _current != null &&
                !p.equals(_current!.parent.path, _current!.path),
            onUp: _goUp,
            upTooltip: strings.parentFolder,
          ),
          if (_fileMode && widget.allowMultiple)
            CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: _multi,
              onChanged: (v) => setState(() {
                _multi = v ?? false;
                if (!_multi) _selected.clear();
              }),
              title: Text(strings.multipleSelection),
            ),
          const Divider(height: 1),
          Expanded(child: _buildList(strings)),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(strings),
    );
  }

  Widget _buildList(AppStrings strings) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(child: Text(strings.emptyFolderTitle));
    }
    return ListView.builder(
      itemCount: _entries.length,
      itemBuilder: (context, i) {
        final ent = _entries[i];
        final name = p.basename(ent.path);
        if (ent is Directory) {
          return ListTile(
            leading: Icon(Icons.folder,
                color: Theme.of(context).colorScheme.primary),
            title: Text(name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _load(ent),
          );
        }
        final file = ent as File;
        final selected = _selected.contains(file.path);
        return ListTile(
          selected: selected,
          leading: _FileLeading(file: file, name: name),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(_formatSize(file)),
          trailing: _multi
              ? Checkbox(
                  value: selected,
                  onChanged: (_) => _onFileTap(file),
                )
              : null,
          onTap: () => _onFileTap(file),
        );
      },
    );
  }

  Widget? _buildBottomBar(AppStrings strings) {
    if (widget.mode == PickMode.directory) {
      return _BottomBar(
        child: FilledButton.icon(
          icon: const Icon(Icons.check),
          label: Text(strings.chooseThisFolder),
          onPressed: _current == null ? null : _confirmDirectory,
        ),
      );
    }
    if (!_multi) return null; // single tap confirms directly
    final n = _selected.length;
    return _BottomBar(
      child: Row(
        children: [
          Text(strings.nSelected(n)),
          const Spacer(),
          FilledButton(
            onPressed: n == 0 ? null : _confirmFiles,
            child: Text('${_confirmLabel(strings)} ($n)'),
          ),
        ],
      ),
    );
  }

  String _formatSize(File file) {
    int bytes;
    try {
      bytes = file.lengthSync();
    } catch (_) {
      return '';
    }
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Thumbnail (for decodable images) or a type icon for a file row.
class _FileLeading extends StatelessWidget {
  const _FileLeading({required this.file, required this.name});

  final File file;
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (canRenderThumbnail(name)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          file,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          cacheWidth: 96,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.image_outlined, color: scheme.primary),
        ),
      );
    }
    final kind = kindForFile(name);
    final icon = switch (kind) {
      EntryKind.image => Icons.image_outlined,
      EntryKind.video => Icons.videocam_outlined,
      EntryKind.note => Icons.description_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
    return Icon(icon, color: scheme.onSurfaceVariant);
  }
}

class _ShortcutsBar extends StatelessWidget {
  const _ShortcutsBar({
    required this.shortcuts,
    required this.currentPath,
    required this.onTap,
  });

  final List<_Shortcut> shortcuts;
  final String? currentPath;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (shortcuts.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: shortcuts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = shortcuts[i];
          final selected =
              currentPath != null && p.equals(currentPath!, s.path);
          return ActionChip(
            avatar: Icon(s.icon, size: 18),
            label: Text(s.label),
            backgroundColor: selected
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
            onPressed: () => onTap(s.path),
          );
        },
      ),
    );
  }
}

class _PathBar extends StatelessWidget {
  const _PathBar({
    required this.path,
    required this.canGoUp,
    required this.onUp,
    required this.upTooltip,
  });

  final String path;
  final bool canGoUp;
  final VoidCallback onUp;
  final String upTooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: upTooltip,
            onPressed: canGoUp ? onUp : null,
          ),
          Expanded(
            child: Text(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SizedBox(height: 48, child: child),
      ),
    );
  }
}
