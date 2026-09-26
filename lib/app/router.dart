import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/assets/presentation/asset_detail_screen.dart';
import '../features/assets/presentation/create_text_screen.dart';
import '../features/folders/presentation/folder_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/trash/presentation/trash_screen.dart';
import 'widgets/app_shell.dart';

/// Application router. All primary destinations are wrapped in [AppShell],
/// which provides the responsive sidebar / bottom navigation.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/folder/:id',
            builder: (context, state) =>
                FolderScreen(folderId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/folder/:id/new-text',
            builder: (context, state) =>
                CreateTextScreen(folderId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/folder/:id/edit-text/:assetId',
            builder: (context, state) => CreateTextScreen(
              folderId: state.pathParameters['id']!,
              assetId: state.pathParameters['assetId'],
            ),
          ),
          GoRoute(
            path: '/asset/:assetId',
            builder: (context, state) =>
                AssetDetailScreen(assetId: state.pathParameters['assetId']!),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/trash',
            builder: (context, state) => const TrashScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
