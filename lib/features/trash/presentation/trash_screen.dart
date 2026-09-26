import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/empty_state.dart';
import '../../folders/application/folders_providers.dart';

/// Trash: soft-deleted folders can be restored. (Deleted assets are handled
/// in a later milestone.)
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final trashed = ref.watch(trashedFoldersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.trash)),
      body: trashed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(strings.genericError)),
        data: (folders) {
          if (folders.isEmpty) {
            return EmptyState(
              icon: Icons.delete_outline,
              title: strings.trash,
              message: strings.noContents,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final folder in folders)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder_delete_outlined),
                    title: Text(folder.name),
                    trailing: IconButton(
                      tooltip: strings.restore,
                      icon: const Icon(Icons.restore),
                      onPressed: () => ref
                          .read(foldersControllerProvider)
                          .restoreFolder(folder),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
