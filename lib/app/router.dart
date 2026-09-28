import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/assistant/presentation/assistant_screen.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/browse_screen.dart';
import '../features/library/presentation/note_screen.dart';
import '../features/library/presentation/preview_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/trash/presentation/trash_screen.dart';
import 'widgets/app_shell.dart';

/// Application router. Filesystem paths travel as the `path` / `dir` query
/// parameter (they contain slashes, so they can't be path segments).
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
            path: '/browse',
            builder: (context, state) {
              final path = state.uri.queryParameters['path'];
              if (path == null) return const HomeScreen();
              return BrowseScreen(dirPath: path);
            },
          ),
          GoRoute(
            path: '/note',
            builder: (context, state) {
              final q = state.uri.queryParameters;
              if (q['path'] == null && q['dir'] == null) {
                return const HomeScreen();
              }
              return NoteScreen(
                existingPath: q['path'],
                newDir: q['dir'],
              );
            },
          ),
          GoRoute(
            path: '/preview',
            builder: (context, state) {
              final path = state.uri.queryParameters['path'];
              if (path == null) return const HomeScreen();
              return PreviewScreen(path: path);
            },
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => SearchScreen(
              initialQuery: state.uri.queryParameters['q'],
            ),
          ),
          GoRoute(
            path: '/favorites',
            builder: (context, state) => const FavoritesScreen(),
          ),
          GoRoute(
            path: '/assistant',
            builder: (context, state) => const AssistantScreen(),
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
