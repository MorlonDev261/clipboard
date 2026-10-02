import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../domain/clean_report.dart';

/// Honest before/after summary of a cleaning run: a status headline, then (on
/// demand) two compact tables — everything the file carried (left) and what was
/// removed (right), with the actual values — plus what is still present and the
/// known limits.
class CleanReportCard extends ConsumerStatefulWidget {
  const CleanReportCard({
    required this.report,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final CleanReport report;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  ConsumerState<CleanReportCard> createState() => _CleanReportCardState();
}

class _CleanReportCardState extends ConsumerState<CleanReportCard> {
  bool _showValues = true;

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final (bg, fg, icon) = switch (report.status) {
      CleanStatus.verifiedClean => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          Icons.verified_outlined,
        ),
      CleanStatus.cleanedWithCaveats => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          Icons.task_alt_outlined,
        ),
      CleanStatus.residualFound || CleanStatus.unsupported => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.warning_amber_outlined,
        ),
      CleanStatus.failed => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.error_outline,
        ),
    };

    final total = _rows(report.before, strings);
    final removed = _rows(report.removed, strings);
    final remaining = _rows(report.remaining, strings);
    final hasTables = total.isNotEmpty || removed.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: fg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.cleanStatusTitle(report.status),
                          style: theme.titleSmall?.copyWith(color: fg),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.errorMessage != null &&
                                  (report.status == CleanStatus.failed ||
                                      report.status == CleanStatus.unsupported)
                              ? '${strings.cleanStatusDetail(report.status)}'
                                  ' (${report.errorMessage})'
                              : strings.cleanStatusDetail(report.status),
                          style: theme.bodySmall?.copyWith(color: fg),
                        ),
                        if (report.hasOutput) ...[
                          const SizedBox(height: 6),
                          Text(
                            report.removed.isEmpty
                                ? strings.cleanNothingFound
                                : strings.cleanRemovedCount(report.removed
                                    .map((f) => f.category)
                                    .toSet()
                                    .length),
                            style: theme.labelMedium?.copyWith(color: fg),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(widget.expanded ? Icons.expand_less : Icons.expand_more,
                      color: fg),
                ],
              ),
            ),
          ),
          if (widget.expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasTables) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: fg,
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () =>
                            setState(() => _showValues = !_showValues),
                        icon: Icon(
                          _showValues
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 14,
                        ),
                        label: Text(_showValues
                            ? strings.cleanHideValues
                            : strings.cleanShowValues),
                      ),
                    ),
                    LayoutBuilder(builder: (context, c) {
                      final left = _MetaTable(
                        title: '${strings.cleanTotalHeading} (${total.length})',
                        rows: total,
                        showValues: _showValues,
                        fg: fg,
                      );
                      final right = _MetaTable(
                        title:
                            '${strings.cleanRemovedHeading} (${removed.length})',
                        rows: removed,
                        showValues: _showValues,
                        fg: fg,
                      );
                      if (c.maxWidth < 480) {
                        return Column(children: [
                          left,
                          const SizedBox(height: 8),
                          right,
                        ]);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: left),
                          const SizedBox(width: 8),
                          Expanded(child: right),
                        ],
                      );
                    }),
                  ],
                  if (remaining.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MetaTable(
                      title:
                          '${strings.cleanRemainingHeading} (${remaining.length})',
                      rows: remaining,
                      showValues: _showValues,
                      fg: fg,
                    ),
                  ],
                  for (final c in report.caveats)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: fg),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              strings.cleanCaveat(c),
                              style: theme.bodySmall?.copyWith(color: fg),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// One row per `name = value`. Findings whose format exposes no values fall
  /// back to `Category | label · size`. Identical rows are merged.
  static List<_Row> _rows(List<MetadataFinding> findings, AppStrings strings) {
    final seen = <String>{};
    final rows = <_Row>[];
    void add(String name, String value) {
      if (seen.add('$name\u0000$value')) rows.add(_Row(name, value));
    }

    for (final f in findings) {
      if (f.entries.isNotEmpty) {
        for (final e in f.entries) {
          add(e.name, e.value);
        }
      } else {
        add(
          strings.metadataCategory(f.category),
          f.bytes > 0 ? '${f.label} · ${_size(f.bytes)}' : f.label,
        );
      }
    }
    return rows;
  }

  static String _size(int b) => b < 1024
      ? '$b B'
      : b < 1024 * 1024
          ? '${(b / 1024).toStringAsFixed(1)} KB'
          : '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _Row {
  const _Row(this.name, this.value);

  final String name;
  final String value;
}

/// A compact two-column table (field | value) in a small type size.
class _MetaTable extends StatelessWidget {
  const _MetaTable({
    required this.title,
    required this.rows,
    required this.showValues,
    required this.fg,
  });

  final String title;
  final List<_Row> rows;
  final bool showValues;
  final Color fg;

  static const _size = 10.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = fg.withValues(alpha: 0.18);
    TextStyle style([FontWeight? w]) =>
        TextStyle(fontSize: _size, height: 1.25, color: fg, fontWeight: w);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(title, style: style(FontWeight.w700)),
          ),
          Divider(height: 1, thickness: 1, color: line),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('—', style: style()),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(3),
                  },
                  border: TableBorder(
                    horizontalInside: BorderSide(color: line, width: 0.5),
                  ),
                  children: [
                    for (final r in rows)
                      TableRow(children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          child: Text(r.name,
                              style: style(FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          child: Text(
                            showValues ? r.value : '••••••',
                            style: style(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
