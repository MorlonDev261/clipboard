import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../providers/workspace_providers.dart';
import 'app_file_picker.dart';
import 'pick_mode.dart';

/// Picks a workspace folder and tells the user when it cannot be used, offering
/// the app's own folder (no permission needed) instead of failing silently.
Future<void> pickWorkspaceWithFeedback(BuildContext context, WidgetRef ref,
    {required String title}) async {
  final strings = ref.read(appStringsProvider);
  final controller = ref.read(workspaceControllerProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  final dirs = await AppFilePicker.pick(
    context,
    mode: PickMode.directory,
    title: title,
  );
  if (dirs.isEmpty) return;
  if (await controller.setRoot(dirs.first)) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(strings.storageDenied),
      action: SnackBarAction(
        label: strings.useAppFolder,
        onPressed: () => controller.useAppFolder(),
      ),
    ));
}
