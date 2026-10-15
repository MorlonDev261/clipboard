import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';

/// Hub reached from the "three bars" tab: accounting, tasks and settings.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;

    Widget item(IconData icon, String label, String route) => ListTile(
          leading: Icon(icon, color: scheme.primary),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(route),
        );

    return Scaffold(
      appBar: AppBar(title: Text(strings.menu)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                item(Icons.account_balance_wallet_outlined, strings.accounting,
                    '/accounting'),
                item(Icons.checklist_rtl_outlined, strings.tasks, '/task'),
                item(Icons.settings_outlined, strings.settings, '/settings'),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'Powered by Morlon Rnd',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
