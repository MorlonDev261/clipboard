import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../constants/app_constants.dart';

/// The app's brand title for the header.
///
/// On the mobile layout (the bottom navigation bar) it shows the logo next to
/// the app name. On desktop/tablet — where the [NavigationRail] on the left
/// already shows the logo — it shows just the name, to avoid duplicating it.
class AppHeaderTitle extends ConsumerWidget {
  const AppHeaderTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;
    final name = Text(strings.appName);
    if (isDesktop) return name;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/icon/icon.png',
          width: 28,
          height: 28,
          filterQuality: FilterQuality.medium,
        ),
        const SizedBox(width: 8),
        name,
      ],
    );
  }
}
