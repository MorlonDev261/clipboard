import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:influencor/app/theme/dialog_sizing.dart';
import 'package:influencor/core/widgets/app_dialog.dart';

void main() {
  Future<double> dialogWidth(WidgetTester tester, double logicalWidth) async {
    tester.view.physicalSize = Size(logicalWidth * 2, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) =>
          Theme(data: wideDialogTheme(context), child: child!),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showAppDialog<void>(
            context,
            builder: (_) => const AppDialog(
              title: 'Titre',
              content: Text('court'),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return tester.getSize(find.byType(AlertDialog)).width;
  }

  testWidgets('phone: dialog takes ~90% of the width', (tester) async {
    final w = await dialogWidth(tester, 390);
    expect(w, greaterThanOrEqualTo(390 * 0.9));
  });

  testWidgets('desktop-size window: dialog is wide enough to be comfortable',
      (tester) async {
    final w = await dialogWidth(tester, 1000);
    expect(w, greaterThanOrEqualTo(420));
  });
}
