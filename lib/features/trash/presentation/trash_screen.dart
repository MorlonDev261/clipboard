import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/empty_state.dart';
import '../../library/application/library_providers.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final trash = ref.watch(trashProvider);
    final controller = ref.read(libraryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.trash),
        actions: [
          trash.maybeWhen(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: strings.emptyTrash,
                    icon: const Icon(Icons.delete_forever_outlined),
                    onPressed: () => _confirmEmpty(context, ref, strings),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: trash.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(strings.genericError)),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.delete_outline,
              title: strings.trash,
              message: strings.trashEmpty,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return Card(
                child: ListTile(
                  leading: Icon(item.isDir
                      ? Icons.folder_delete_outlined
                      : Icons.insert_drive_file_outlined),
                  title: Text(item.name),
                  subtitle: Text(item.originalPath),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: strings.restore,
                        icon: const Icon(Icons.restore),
                        onPressed: () => controller.restoreFromTrash(item.id),
                      ),
                      IconButton(
                        tooltip: strings.deletePermanently,
                        icon: const Icon(Icons.delete_forever),
                        onPressed: () => controller.deleteForever(item.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmEmpty(
      BuildContext context, WidgetRef ref, AppStrings strings) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.emptyTrashTitle),
        content: Text(strings.emptyTrashMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.emptyTrash),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(libraryControllerProvider).emptyTrash();
    }
  }
}
