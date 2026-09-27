import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/l10n/app_strings.dart';
import '../application/library_providers.dart';
import '../domain/library_entry.dart';
import 'browse_screen.dart' show confirmDelete;
import 'widgets/video_preview.dart';

/// Previews a media/other file: images render inline; videos and other files
/// show info with an "open externally" action.
class PreviewScreen extends ConsumerWidget {
  const PreviewScreen({required this.path, super.key});

  final String path;

  Future<void> _openExternally() async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {
      // best effort
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final parent = p.dirname(path);
    final listing = ref.watch(directoryProvider(parent));
    final controller = ref.read(libraryControllerProvider);

    final entry =
        listing.value?.firstWhereOrNull((e) => p.equals(e.path, path));

    final kind = entry?.kind ?? kindForFile(p.basename(path));
    final isFavorite = entry?.isFavorite ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(path)),
        actions: [
          IconButton(
            tooltip: isFavorite
                ? strings.removeFromFavorites
                : strings.addToFavorites,
            icon: Icon(isFavorite ? Icons.star : Icons.star_border),
            onPressed: () =>
                controller.setFavorite(path, !isFavorite, parentDir: parent),
          ),
          IconButton(
            tooltip: strings.open,
            icon: const Icon(Icons.open_in_new),
            onPressed: _openExternally,
          ),
          IconButton(
            tooltip: strings.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmDelete(context, strings);
              if (ok != true) return;
              await controller.moveToTrash(path, parentDir: parent);
              if (!context.mounted) return;
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: switch (kind) {
          EntryKind.image when canRenderThumbnail(p.basename(path)) =>
            InteractiveViewer(
              maxScale: 5,
              child: Image.file(
                File(path),
                errorBuilder: (_, __, ___) => _Info(
                    icon: Icons.broken_image_outlined,
                    text: strings.genericError),
              ),
            ),
          EntryKind.image => _Info(
              icon: Icons.image_outlined,
              text: p.basename(path),
              actionLabel: strings.open,
              onAction: _openExternally,
            ),
          EntryKind.video => VideoPreview(path: path),
          _ => _Info(
              icon: Icons.insert_drive_file_outlined,
              text: p.basename(path),
              actionLabel: strings.open,
              onAction: _openExternally,
            ),
        },
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
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
              icon: const Icon(Icons.open_in_new),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
