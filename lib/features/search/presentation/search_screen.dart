import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/empty_state.dart';

/// Global search. Full-text search across assets, folders and posts is a
/// later milestone; this is the navigable placeholder.
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(strings.search)),
      body: EmptyState(
        icon: Icons.search,
        title: strings.search,
        message: strings.comingSoon,
      ),
    );
  }
}
