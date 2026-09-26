import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../constants/app_constants.dart';

/// Top-level responsive navigation shell.
///
/// * Mobile (< [AppConstants.desktopBreakpoint]): bottom [NavigationBar].
/// * Desktop / tablet: persistent [NavigationRail] sidebar.
class AppShell extends ConsumerWidget {
  const AppShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  static const _destinations = <_Destination>[
    _Destination('/', Icons.home_outlined, Icons.home),
    _Destination('/search', Icons.search_outlined, Icons.search),
    _Destination('/favorites', Icons.star_border, Icons.star),
    _Destination('/trash', Icons.delete_outline, Icons.delete),
    _Destination('/settings', Icons.settings_outlined, Icons.settings),
  ];

  int get _selectedIndex {
    // Browse / note / preview routes belong to the "home" tab.
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/favorites')) return 2;
    if (location.startsWith('/trash')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  void _onSelect(BuildContext context, int index) {
    context.go(_destinations[index].route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final labels = [
      strings.home,
      strings.search,
      strings.favorites,
      strings.trash,
      strings.settings,
    ];
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => _onSelect(context, i),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Icon(Icons.content_paste_rounded),
              ),
              destinations: [
                for (var i = 0; i < _destinations.length; i++)
                  NavigationRailDestination(
                    icon: Icon(_destinations[i].icon),
                    selectedIcon: Icon(_destinations[i].selectedIcon),
                    label: Text(labels[i]),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => _onSelect(context, i),
        destinations: [
          for (var i = 0; i < _destinations.length; i++)
            NavigationDestination(
              icon: Icon(_destinations[i].icon),
              selectedIcon: Icon(_destinations[i].selectedIcon),
              label: labels[i],
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.route, this.icon, this.selectedIcon);
  final String route;
  final IconData icon;
  final IconData selectedIcon;
}
