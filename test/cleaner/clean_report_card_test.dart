import 'package:clipboard/features/cleaner/domain/clean_report.dart';
import 'package:clipboard/features/cleaner/presentation/clean_report_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('report card renders every status with its details',
      (tester) async {
    const gps = MetadataFinding(MetadataCategory.gps, 'GPS');
    const orientation = MetadataFinding(
        MetadataCategory.orientation, 'Orientation 6',
        sensitive: false);
    final reports = [
      const CleanReport(
        status: CleanStatus.verifiedClean,
        format: MediaFormat.jpeg,
        outputPath: 'x.jpg',
        before: [gps, orientation],
        after: [orientation],
      ),
      const CleanReport(
        status: CleanStatus.cleanedWithCaveats,
        format: MediaFormat.isoVideo,
        outputPath: 'x.mp4',
        before: [gps],
        caveats: {CleanCaveat.unsupportedCodecStream},
      ),
      const CleanReport(
        status: CleanStatus.residualFound,
        format: MediaFormat.png,
        outputPath: 'x.png',
        before: [gps],
        after: [gps],
      ),
      const CleanReport(
          status: CleanStatus.unsupported,
          format: MediaFormat.heif,
          before: [gps]),
      const CleanReport(
          status: CleanStatus.failed,
          format: MediaFormat.jpeg,
          errorMessage: 'Truncated JPEG'),
    ];
    for (final report in reports) {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CleanReportCard(
                  report: report, expanded: true, onToggle: () {}),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull, reason: report.status.name);
      expect(find.byType(CleanReportCard), findsOneWidget);
    }
    expect(find.textContaining('Truncated JPEG'), findsOneWidget);
  });

  testWidgets('shows the values in two tables and can hide them',
      (tester) async {
    const report = CleanReport(
      status: CleanStatus.verifiedClean,
      format: MediaFormat.jpeg,
      outputPath: 'x.jpg',
      before: [
        MetadataFinding(MetadataCategory.gps, 'GPS',
            entries: [MetadataEntry('GPS Latitude', '48.85660° N')]),
        MetadataFinding(MetadataCategory.orientation, 'Orientation 6',
            sensitive: false,
            entries: [
              MetadataEntry('Orientation', '6 (rotated 90° clockwise)')
            ]),
      ],
      after: [
        MetadataFinding(MetadataCategory.orientation, 'Orientation 6',
            sensitive: false),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CleanReportCard(
                report: report, expanded: true, onToggle: () {}),
          ),
        ),
      ),
    ));
    expect(find.text('Total (2)'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^(Supprimé|Removed) \(1\)$')),
        findsOneWidget);
    // GPS value appears in both tables; orientation only in the total table.
    expect(find.text('48.85660° N'), findsNWidgets(2));
    expect(find.text('6 (rotated 90° clockwise)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(find.text('48.85660° N'), findsNothing);
    expect(find.text('••••••'), findsNWidgets(3));
  });
}
