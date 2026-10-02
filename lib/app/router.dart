import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/about/presentation/about_screen.dart';
import '../features/assistant/presentation/assistant_screen.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/browse_screen.dart';
import '../features/library/presentation/note_screen.dart';
import '../features/library/presentation/preview_screen.dart';
import '../features/library/presentation/table_screen.dart';
import '../features/reseller/presentation/reseller_login_screen.dart';
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
              final extra = state.extra;
              return PreviewScreen(
                path: path,
                paths: extra is List<String> ? extra : null,
              );
            },
          ),
          GoRoute(
            path: '/table',
            builder: (context, state) {
              final path = state.uri.queryParameters['path'];
              if (path == null) return const HomeScreen();
              return TableScreen(path: path);
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
            pageBuilder: (context, state) => _assistantPage(
              state,
              const AssistantScreen(),
            ),
          ),
          GoRoute(
            path: '/deganeo',
            pageBuilder: (context, state) => _assistantPage(
              state,
              const AssistantScreen(section: AssistantSection.deganeo),
            ),
          ),
          GoRoute(
            path: '/trash',
            builder: (context, state) => const TrashScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/about',
            builder: (context, state) => const AboutScreen(),
          ),
          GoRoute(
            path: '/pro',
            builder: (context, state) => const ResellerLoginScreen(),
          ),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _assistantPage(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
