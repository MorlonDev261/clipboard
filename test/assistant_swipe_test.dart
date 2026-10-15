import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:influencor/core/providers/settings_providers.dart';
import 'package:influencor/core/services/settings_service.dart';
import 'package:influencor/features/assistant/presentation/assistant_screen.dart';

class _FakeSettings extends SettingsService {
  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async {}
}

Widget _app(GoRouter router) => ProviderScope(
      overrides: [settingsServiceProvider.overrideWithValue(_FakeSettings())],
      child: MaterialApp.router(routerConfig: router),
    );

GoRouter _router(String initial) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/assistant',
          pageBuilder: (_, state) => const NoTransitionPage(
            key: ValueKey('assistant-shell'),
            child: AssistantScreen(),
          ),
        ),
        GoRoute(
          path: '/deganeo',
          pageBuilder: (_, state) => const NoTransitionPage(
            key: ValueKey('assistant-shell'),
            child: AssistantScreen(section: AssistantSection.deganeo),
          ),
        ),
      ],
    );

void main() {
  testWidgets('the pager follows the finger, then the route follows the page',
      (tester) async {
    final router = _router('/assistant');
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-page')), findsOneWidget);

    final pager = find.byType(PageView);
    final controller = tester.widget<PageView>(pager).controller!;

    // Half-way through a drag: the page is mid-way, not snapped.
    final gesture = await tester.startGesture(tester.getCenter(pager));
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump();
    expect(controller.page, greaterThan(0.1));
    expect(controller.page, lessThan(0.9));

    await gesture.moveBy(const Offset(-300, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.page, 1.0);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/deganeo',
    );
    expect(find.byKey(const ValueKey('deganeo-page')), findsOneWidget);

    // And back, with the chat page kept alive meanwhile.
    final back = await tester.startGesture(tester.getCenter(pager));
    await back.moveBy(const Offset(30, 0)); // past the touch slop
    await tester.pump();
    await back.moveBy(const Offset(170, 0));
    await tester.pump();
    expect(controller.page, lessThan(0.95));
    await back.moveBy(const Offset(300, 0));
    await back.up();
    await tester.pumpAndSettle();
    expect(controller.page, 0.0);
    expect(router.routeInformationProvider.value.uri.path, '/assistant');
  });

  testWidgets('tapping a header tab slides to that page', (tester) async {
    final router = _router('/assistant');
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deganeo').first);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/deganeo');
  });

  testWidgets('a route change from outside slides the pager', (tester) async {
    final router = _router('/assistant');
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    router.go('/deganeo');
    await tester.pumpAndSettle();
    final controller =
        tester.widget<PageView>(find.byType(PageView)).controller;
    expect(controller!.page, 1.0);
  });
}
