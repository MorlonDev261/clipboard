import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

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
  final _columnControllers = <String, TextEditingController>{};
  final _cellControllers = <String, TextEditingController>{};

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

    return Scaffold(
      appBar: AppBar(
        title: Text(p.basenameWithoutExtension(widget.path)),
        actions: [
          if (_draft != null)
            IconButton(
              tooltip: _editing ? strings.cancel : strings.edit,
              icon: Icon(_editing ? Icons.close : Icons.edit_outlined),
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _editing = !_editing;
                      }),
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

    return Center(
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Table(
                          defaultColumnWidth: const IntrinsicColumnWidth(),
                          border: TableBorder.all(color: borderColor),
                          children: [
                            TableRow(
                              decoration:
                                  BoxDecoration(color: scheme.primaryContainer),
                              children: [
                                for (final column in table.columns)
                                  _HeaderCell(
                                    controller: columnControllers[column.id],
                                    title: column.title,
                                    editing: editing,
                                    onChanged: (value) =>
                                        onColumnChanged(column.id, value),
                                  ),
                              ],
                            ),
                            for (final row in table.rows)
                              TableRow(
                                children: [
                                  for (final column in table.columns)
                                    _BodyCell(
                                      controller: cellControllers[
                                          '${row.id}::${column.id}'],
                                      value: row.cells[column.id] ?? '',
                                      editing: editing,
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
                    ),
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
  });

  final TextEditingController? controller;
  final String title;
  final bool editing;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 260),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: editing && controller != null
            ? TextField(
                controller: controller,
                onChanged: onChanged,
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              )
            : Text(
                title,
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell({
    required this.controller,
    required this.value,
    required this.editing,
    required this.onChanged,
  });

  final TextEditingController? controller;
  final String value;
  final bool editing;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 260),
      child: Padding(
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
      ),
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
    return IconButton.filledTonal(
      tooltip: tooltip,
      icon: const Icon(Icons.add),
      onPressed: onPressed,
    );
  }
}
