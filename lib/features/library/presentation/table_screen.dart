import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../app/constants/app_constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../application/library_providers.dart';
import '../domain/table_document.dart';

class TableScreen extends ConsumerStatefulWidget {
  const TableScreen({required this.path, super.key});

  final String path;

  @override
  ConsumerState<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends ConsumerState<TableScreen> {
  static const _uuid = Uuid();

  TableDocument? _draft;
  String? _loadedSignature;
  bool _editing = false;
  bool _dirty = false;
  bool _saving = false;
  bool _showHiddenColumns = false;
  final _columnControllers = <String, TextEditingController>{};
  final _cellControllers = <String, TextEditingController>{};

  void _toggleHiddenColumns([AppStrings? strings]) {
    HapticFeedback.mediumImpact();
    setState(() {
      _showHiddenColumns = !_showHiddenColumns;
    });
    if (strings != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _showHiddenColumns
                  ? strings.showHiddenColumns
                  : strings.hideHiddenColumns,
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  void dispose() {
    for (final controller in _columnControllers.values) {
      controller.dispose();
    }
    for (final controller in _cellControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncDraft(TableDocument table) {
    final signature = table.toPrettyJson();
    if (_dirty || _loadedSignature == signature) return;
    _draft = table;
    _loadedSignature = signature;
    _resetControllers(table);
  }

  void _resetControllers(TableDocument table) {
    for (final controller in _columnControllers.values) {
      controller.dispose();
    }
    for (final controller in _cellControllers.values) {
      controller.dispose();
    }
    _columnControllers
      ..clear()
      ..addEntries(table.columns.map(
        (column) => MapEntry(
          column.id,
          TextEditingController(text: column.title),
        ),
      ));
    _cellControllers.clear();
    for (final row in table.rows) {
      for (final column in table.columns) {
        _cellControllers[_cellKey(row.id, column.id)] =
            TextEditingController(text: row.cells[column.id] ?? '');
      }
    }
  }

  String _cellKey(String rowId, String columnId) => '$rowId::$columnId';

  void _markDirty(TableDocument table) {
    _draft = table;
    _dirty = true;
  }

  void _updateColumnTitle(String columnId, String value) {
    final table = _draft;
    if (table == null) return;
    _markDirty(TableDocument(
      columns: [
        for (final column in table.columns)
          column.id == columnId
              ? TableColumnDef(
                  id: column.id,
                  title: value.trim().isEmpty ? column.title : value,
                  type: column.type,
                )
              : column,
      ],
      rows: table.rows,
    ));
  }

  void _updateCell(String rowId, String columnId, String value) {
    final table = _draft;
    if (table == null) return;
    _markDirty(TableDocument(
      columns: table.columns,
      rows: [
        for (final row in table.rows)
          row.id == rowId
              ? TableRowData(
                  id: row.id,
                  cells: {
                    ...row.cells,
                    columnId: value,
                  },
                )
              : row,
      ],
    ));
  }

  void _addColumn(AppStrings strings) {
    final table = _draft;
    if (table == null) return;
    final id = _uuid.v4();
    final title = '${strings.columnName} ${table.columns.length + 1}';
    setState(() {
      _columnControllers[id] = TextEditingController(text: title);
      for (final row in table.rows) {
        _cellControllers[_cellKey(row.id, id)] = TextEditingController();
      }
      _markDirty(TableDocument(
        columns: [...table.columns, TableColumnDef(id: id, title: title)],
        rows: [
          for (final row in table.rows)
            TableRowData(
              id: row.id,
              cells: {
                ...row.cells,
                id: '',
              },
            ),
        ],
      ));
    });
  }

  void _addRow() {
    final table = _draft;
    if (table == null) return;
    final id = _uuid.v4();
    final cells = {
      for (final column in table.columns) column.id: '',
    };
    setState(() {
      for (final column in table.columns) {
        _cellControllers[_cellKey(id, column.id)] = TextEditingController();
      }
      _markDirty(TableDocument(
        columns: table.columns,
        rows: [
          ...table.rows,
          TableRowData(id: id, cells: cells),
        ],
      ));
    });
  }

  Future<void> _save(AppStrings strings) async {
    final table = _draft;
    if (table == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(libraryControllerProvider).saveTable(widget.path, table);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
        _dirty = false;
        _showHiddenColumns = false;
        _loadedSignature = table.toPrettyJson();
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(strings.noteSaved)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(strings.genericError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final table = ref.watch(tableDocumentProvider(widget.path));
    // Sync before the app bar is built: its edit button needs the draft, and
    // the body (which also syncs) is built after it.
    if (table.value case final data?) _syncDraft(data);

    return Scaffold(
      appBar: AppBar(
        title: Text(p.basenameWithoutExtension(widget.path)),
        actions: [
          if (_draft != null)
            // Long press toggles the hidden ([…]) columns. The tooltip only
            // shows on mouse hover: as a long-press tooltip (the touch
            // default) it would swallow that gesture.
            Tooltip(
              message: _editing ? strings.cancel : strings.edit,
              triggerMode: TooltipTriggerMode.manual,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress:
                    _saving ? null : () => _toggleHiddenColumns(strings),
                child: IconButton(
                  icon: Icon(_editing ? Icons.close : Icons.edit_outlined),
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _editing = !_editing;
                            if (!_editing) _showHiddenColumns = false;
                          }),
                ),
              ),
            ),
          if (_editing && _draft != null)
            IconButton(
              tooltip: strings.save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              onPressed: _saving ? null : () => _save(strings),
            ),
        ],
      ),
      body: table.when(
        loading: () => _draft == null
            ? const Center(child: CircularProgressIndicator())
            : _TableCanvas(
                table: _draft!,
                editing: _editing,
                showHiddenColumns: _showHiddenColumns,
                onToggleHiddenColumns: _toggleHiddenColumns,
                strings: strings,
                columnControllers: _columnControllers,
                cellControllers: _cellControllers,
                onColumnChanged: _updateColumnTitle,
                onCellChanged: _updateCell,
                onAddColumn: () => _addColumn(strings),
                onAddRow: _addRow,
                addColumnTooltip: strings.addTableColumn,
                addRowTooltip: strings.addTableRow,
              ),
        error: (_, __) => Center(child: Text(strings.genericError)),
        data: (data) {
          if (data == null) {
            return Center(child: Text(strings.incompatibleTable));
          }
          _syncDraft(data);
          final draft = _draft ?? data;
          return _TableCanvas(
            table: draft,
            editing: _editing,
            showHiddenColumns: _showHiddenColumns,
            onToggleHiddenColumns: _toggleHiddenColumns,
            strings: strings,
            columnControllers: _columnControllers,
            cellControllers: _cellControllers,
            onColumnChanged: _updateColumnTitle,
            onCellChanged: _updateCell,
            onAddColumn: () => _addColumn(strings),
            onAddRow: _addRow,
            addColumnTooltip: strings.addTableColumn,
            addRowTooltip: strings.addTableRow,
          );
        },
      ),
    );
  }
}

class _TableCanvas extends StatelessWidget {
  const _TableCanvas({
    required this.table,
    required this.editing,
    required this.showHiddenColumns,
    required this.onToggleHiddenColumns,
    required this.strings,
    required this.columnControllers,
    required this.cellControllers,
    required this.onColumnChanged,
    required this.onCellChanged,
    required this.onAddColumn,
    required this.onAddRow,
    required this.addColumnTooltip,
    required this.addRowTooltip,
  });

  final TableDocument table;
  final bool editing;
  final bool showHiddenColumns;
  final VoidCallback onToggleHiddenColumns;
  final AppStrings strings;
  final Map<String, TextEditingController> columnControllers;
  final Map<String, TextEditingController> cellControllers;
  final void Function(String columnId, String value) onColumnChanged;
  final void Function(String rowId, String columnId, String value)
      onCellChanged;
  final VoidCallback onAddColumn;
  final VoidCallback onAddRow;
  final String addColumnTooltip;
  final String addRowTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = scheme.outlineVariant;
    final isMobile =
        MediaQuery.sizeOf(context).width < AppConstants.desktopBreakpoint;
    final padding = isMobile ? 12.0 : 20.0;

    final displayedColumns = showHiddenColumns
        ? table.columns
        : table.columns
            .where((c) => !TableDocument.isBracketColumnTitle(c.title))
            .toList();

    final Widget tableWidget;
    if (displayedColumns.isEmpty) {
      tableWidget = DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
          color: scheme.surfaceContainerLow,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility_off_outlined,
                  size: 36, color: scheme.primary),
              const SizedBox(height: 10),
              Text(
                strings.allColumnsHidden,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                strings.longPressToToggleColumns,
                style: TextStyle(fontSize: 13, color: scheme.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      tableWidget = DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Table(
            defaultColumnWidth: isMobile
                ? const FlexColumnWidth(1)
                : const IntrinsicColumnWidth(),
            columnWidths: isMobile
                ? {
                    for (var i = 0; i < displayedColumns.length; i++)
                      i: const FlexColumnWidth(1),
                  }
                : null,
            border: TableBorder.all(color: borderColor),
            children: [
              TableRow(
                decoration: BoxDecoration(color: scheme.primaryContainer),
                children: [
                  for (final column in displayedColumns)
                    _HeaderCell(
                      controller: columnControllers[column.id],
                      title: column.title,
                      editing: editing,
                      fullWidth: isMobile,
                      onChanged: (value) => onColumnChanged(column.id, value),
                    ),
                ],
              ),
              for (final row in table.rows)
                TableRow(
                  children: [
                    for (final column in displayedColumns)
                      _BodyCell(
                        controller: cellControllers['${row.id}::${column.id}'],
                        value: row.cells[column.id] ?? '',
                        editing: editing,
                        fullWidth: isMobile,
                        onChanged: (value) => onCellChanged(
                          row.id,
                          column.id,
                          value,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    final animatedTable = AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey(
              'table_view_${displayedColumns.map((c) => c.id).join('_')}'),
          child: tableWidget,
        ),
      ),
    );

    return Center(
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: isMobile
              // Phone: the table fills the width (flex columns), the plus
              // buttons sit side by side underneath.
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    animatedTable,
                    if (editing) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _PlusButton(
                            tooltip: addColumnTooltip,
                            onPressed: onAddColumn,
                          ),
                          const SizedBox(width: 8),
                          _PlusButton(
                            tooltip: addRowTooltip,
                            onPressed: onAddRow,
                          ),
                        ],
                      ),
                    ],
                  ],
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          animatedTable,
                          if (editing) ...[
                            const SizedBox(width: 8),
                            _PlusButton(
                              tooltip: addColumnTooltip,
                              onPressed: onAddColumn,
                            ),
                          ],
                        ],
                      ),
                      if (editing) ...[
                        const SizedBox(height: 8),
                        _PlusButton(
                          tooltip: addRowTooltip,
                          onPressed: onAddRow,
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.controller,
    required this.title,
    required this.editing,
    required this.onChanged,
    this.fullWidth = false,
  });

  final TextEditingController? controller;
  final String title;
  final bool editing;
  final bool fullWidth;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isBracketed = TableDocument.isBracketColumnTitle(title);

    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: editing && controller != null
          ? TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                prefixIcon: isBracketed
                    ? Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.visibility_off_outlined,
                          size: 16,
                          color:
                              scheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      )
                    : null,
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 20, maxHeight: 20),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isBracketed) ...[
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 15,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
    );
    if (fullWidth) return child;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 260),
      child: child,
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell({
    required this.controller,
    required this.value,
    required this.editing,
    required this.onChanged,
    this.fullWidth = false,
  });

  final TextEditingController? controller;
  final String value;
  final bool editing;
  final bool fullWidth;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: editing && controller != null
          ? TextField(
              controller: controller,
              onChanged: onChanged,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            )
          : Text(value.isEmpty ? ' ' : value),
    );
    if (fullWidth) return child;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 260),
      child: child,
    );
  }
}

class _PlusButton extends StatelessWidget {
  const _PlusButton({
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Material(
          color: scheme.secondaryContainer,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Center(
              child: Icon(
                Icons.add,
                size: 24,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
