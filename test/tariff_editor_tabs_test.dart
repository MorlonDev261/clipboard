import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:influencor/core/widgets/one_page_scroll.dart';
import 'package:influencor/features/fees/data/madagascar_tariffs.dart';
import 'package:influencor/features/fees/presentation/tariff_editor_screen.dart';

void main() {
  Future<void> open(WidgetTester tester, {int operator = 1}) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: TariffEditorScreen(tariff: madagascarTariffs[operator]),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final rows = find.descendant(
      of: find.byType(AppTabBarView), matching: find.byType(ListTile));

  int tabIndex(WidgetTester tester) =>
      DefaultTabController.of(tester.element(find.byType(AppTabBarView))).index;

  Future<void> swipe(WidgetTester tester, double dx) async {
    await tester.fling(find.byType(AppTabBarView), Offset(dx, 0), 800);
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a tab selects it and shows its page', (tester) async {
    await open(tester);
    expect(tabIndex(tester), 0);

    await tester.ensureVisible(find.byType(Tab).at(1));
    await tester.tap(find.byType(Tab).at(1), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tabIndex(tester), 1);
    // Same-operator transfer (Orange → Orange) starts at 65 Ar.
    expect(find.textContaining('65'), findsWidgets);
  });

  testWidgets('swiping moves the selected tab one page at a time',
      (tester) async {
    await open(tester);
    final seen = <int>[];
    for (final dx in [-300.0, -300.0, -300.0, 300.0, 300.0]) {
      await swipe(tester, dx);
      seen.add(tabIndex(tester));
    }
    expect(seen, [1, 2, 3, 2, 1]);
  });

  testWidgets('one swipe never skips pages, however long or fast',
      (tester) async {
    await open(tester);
    // Gestures wider than the screen (400 dp) and very fast.
    for (final (dx, speed) in [
      (-900.0, 800.0),
      (-900.0, 5000.0),
      (-1500.0, 9000.0),
      (900.0, 5000.0),
      (900.0, 9000.0),
    ]) {
      final before = tabIndex(tester);
      await tester.fling(find.byType(AppTabBarView), Offset(dx, 0), speed);
      await tester.pumpAndSettle();
      final after = tabIndex(tester);
      expect((after - before).abs() <= 1, isTrue,
          reason: 'dx=$dx speed=$speed moved $before -> $after');
    }
    // Slow long drags too.
    for (final dx in [-1200.0, -1200.0, 1200.0]) {
      final before = tabIndex(tester);
      await tester.drag(find.byType(AppTabBarView), Offset(dx, 0));
      await tester.pumpAndSettle();
      expect((tabIndex(tester) - before).abs() <= 1, isTrue,
          reason: 'drag $dx');
    }
  });

  testWidgets('all four tabs fit on a phone, so the tab bar never scrolls',
      (tester) async {
    await open(tester);
    final bar = tester.widget<TabBar>(find.byType(TabBar));
    expect(bar.isScrollable, isFalse);
    for (var i = 0; i < 4; i++) {
      final box = tester.getRect(find.byType(Tab).at(i));
      expect(box.left >= 0 && box.right <= 400, isTrue, reason: 'tab $i');
    }
  });

  testWidgets('tapping a far tab still jumps there', (tester) async {
    await open(tester);
    // Tab 0 -> tab 2 by tap (not a swipe) must not be blocked.
    await tester.tap(find.byType(Tab).at(2));
    await tester.pumpAndSettle();
    expect(tabIndex(tester), 2);
  });

  testWidgets('a bracket added in one tab is still there after switching',
      (tester) async {
    // Airtel has no "via app" grid: that last page starts empty.
    await open(tester, operator: 2);
    for (var i = 0; i < 3; i++) {
      await swipe(tester, -300);
    }
    expect(tabIndex(tester), 3);
    expect(rows, findsNothing);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).last); // save suggested row
    await tester.pumpAndSettle();
    expect(rows, findsOneWidget);

    await swipe(tester, 300);
    await swipe(tester, -300);
    expect(tabIndex(tester), 3);
    expect(rows, findsOneWidget);
  });
}
