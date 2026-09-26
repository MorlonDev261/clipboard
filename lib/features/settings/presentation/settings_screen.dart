import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_constants.dart';
import '../../../core/l10n/app_strings.dart';

/// Settings placeholder. Theme mode, default view, file-size limits, export
/// and about are wired in a later milestone.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(strings.appName),
            subtitle: Text('${AppConstants.appName} — MVP'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(strings.settings),
            subtitle: Text(strings.comingSoon),
          ),
        ],
      ),
    );
  }
}
