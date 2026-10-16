import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../domain/clean_report.dart';
import 'clean_report_card.dart';

/// What a file carries *before* cleaning: a searchable `tag | value` table
/// (type "GPS" or "Date" to find an entry), shown for the selected file.
class MetadataInspectorCard extends ConsumerStatefulWidget {
  const MetadataInspectorCard({required this.findings, super.key});

  /// `null` while the file is still being read.
  final List<MetadataFinding>? findings;

  @override
  ConsumerState<MetadataInspectorCard> createState() =>
      _MetadataInspectorCardState();
}

class _MetadataInspectorCardState extends ConsumerState<MetadataInspectorCard> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final findings = widget.findings;
    final fg = scheme.onSurface;

    if (findings == null) {
      return _frame(
        scheme,
        Row(children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(strings.inspectingFile),
        ]),
      );
    }

    final all = metaRows(findings.where((f) => f.sensitive).toList(), strings);
    if (all.isEmpty) {
      return _frame(
        scheme,
        Row(children: [
          Icon(Icons.verified_outlined, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(strings.noMetadataFound)),
        ]),
      );
    }

    final q = _query.trim().toLowerCase();
    final rows = q.isEmpty
        ? all
        : all
            .where((r) =>
                r.name.toLowerCase().contains(q) ||
                r.value.toLowerCase().contains(q))
            .toList();

    return _frame(
      scheme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.metadataFoundCount(all.length),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: strings.searchMetadata,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          MetaTable(
            title: '${strings.cleanTotalHeading} (${rows.length})',
            rows: rows,
            showValues: true,
            fg: fg,
          ),
        ],
      ),
    );
  }

  Widget _frame(ColorScheme scheme, Widget child) => DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      );
}
