import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:influencor/features/library/application/library_providers.dart';
import 'package:influencor/features/library/domain/table_document.dart';
import 'package:influencor/features/library/presentation/table_screen.dart';

void main() {
  group('TableDocument.isBracketColumnTitle', () {
    test('detects column names enclosed in square brackets', () {
      expect(TableDocument.isBracketColumnTitle('[Notes]'), isTrue);
      expect(TableDocument.isBracketColumnTitle('[Prix Achat]'), isTrue);
      expect(TableDocument.isBracketColumnTitle('[x]'), isTrue);
      expect(TableDocument.isBracketColumnTitle('[]'), isTrue);
      expect(TableDocument.isBracketColumnTitle('  [Secret]  '), isTrue);
    });

    test('rejects unbracketed or malformed column names', () {
      expect(TableDocument.isBracketColumnTitle('Notes'), isFalse);
      expect(TableDocument.isBracketColumnTitle('[Notes'), isFalse);
      expect(TableDocument.isBracketColumnTitle('Notes]'), isFalse);
      expect(TableDocument.isBracketColumnTitle(''), isFalse);
      expect(TableDocument.isBracketColumnTitle('['), isFalse);
      expect(TableDocument.isBracketColumnTitle(']'), isFalse);
    });

    test('TableColumnDef.isBracketed delegates to helper', () {
      const col1 = TableColumnDef(id: '1', title: '[Cache]');
      const col2 = TableColumnDef(id: '2', title: 'Visible');
      expect(col1.isBracketed, isTrue);
      expect(col2.isBracketed, isFalse);
    });
  });

  group('TableScreen hidden columns toggle and edit controls', () {
    testWidgets(
        'no plus button in view mode, long press edit toggles hidden columns',
        (tester) async {
      const path = '/workspace/test.table';
      final testTable = TableDocument(
        columns: const [
          TableColumnDef(id: 'c1', title: 'Nom'),
          TableColumnDef(id: 'c2', title: '[Secret]'),
        ],
        rows: const [
          TableRowData(id: 'r1', cells: {'c1': 'Jean', 'c2': '1234'}),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tableDocumentProvider(path).overrideWith((ref) => testTable),
          ],
          child: const MaterialApp(
            home: TableScreen(path: path),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // In view mode:
      // 1. Plus button must NOT be present
      expect(find.byIcon(Icons.add), findsNothing);

      // 2. Visible column is shown, bracketed hidden column is hidden
      expect(find.text('Nom'), findsOneWidget);
      expect(find.text('[Secret]'), findsNothing);

      // 3. Edit icon is present
      final editButton = find.byIcon(Icons.edit_outlined);
      expect(editButton, findsOneWidget);

      // 4. Long press on edit icon toggles hidden columns
      await tester.longPress(editButton);
      await tester.pumpAndSettle();

      // Now [Secret] should be visible
      expect(find.text('[Secret]'), findsOneWidget);
      // Plus button still not present because we are not in edit mode
      expect(find.byIcon(Icons.add), findsNothing);

      // 5. Long press again hides [Secret]
      await tester.longPress(editButton);
      await tester.pumpAndSettle();
      expect(find.text('[Secret]'), findsNothing);

      // 6. Normal tap on edit button enters edit mode
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Edit mode is active (cancel/close icon displayed, plus button appears)
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
    });
  });
}
