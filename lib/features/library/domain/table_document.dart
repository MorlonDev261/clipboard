import 'dart:convert';
import 'dart:io';

/// JSON schema marker used to recognise app-compatible table files.
const tableDocumentType = 'influencor.table';
const tableDocumentVersion = 1;

class TableColumnDef {
  const TableColumnDef({
    required this.id,
    required this.title,
    this.type = 'text',
  });

  final String id;
  final String title;
  final String type;

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'type': type,
      };
}

class TableRowData {
  const TableRowData({
    required this.id,
    required this.cells,
  });

  final String id;
  final Map<String, String> cells;

  Map<String, Object> toJson() => {
        'id': id,
        'cells': cells,
      };
}

class TableDocument {
  const TableDocument({
    required this.columns,
    required this.rows,
  });

  final List<TableColumnDef> columns;
  final List<TableRowData> rows;

  static bool looksCompatible(Object? decoded) => tryParse(decoded) != null;

  static TableDocument? tryParse(Object? decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['type'] != tableDocumentType) return null;
    if (decoded['version'] != tableDocumentVersion) return null;

    final rawColumns = decoded['columns'];
    if (rawColumns is! List || rawColumns.isEmpty) return null;
    final columns = <TableColumnDef>[];
    final columnIds = <String>{};
    for (final raw in rawColumns) {
      if (raw is! Map<String, dynamic>) return null;
      final id = raw['id'];
      final title = raw['title'];
      final type = raw['type'] ?? 'text';
      if (id is! String || id.trim().isEmpty) return null;
      if (title is! String || title.trim().isEmpty) return null;
      if (type is! String || type.trim().isEmpty) return null;
      if (!columnIds.add(id)) return null;
      columns.add(TableColumnDef(
        id: id,
        title: title,
        type: type,
      ));
    }

    final rawRows = decoded['rows'];
    if (rawRows is! List) return null;
    final rows = <TableRowData>[];
    final rowIds = <String>{};
    for (final raw in rawRows) {
      if (raw is! Map<String, dynamic>) return null;
      final id = raw['id'];
      final cells = raw['cells'];
      if (id is! String || id.trim().isEmpty) return null;
      if (!rowIds.add(id)) return null;
      if (cells is! Map<String, dynamic>) return null;
      final normalized = <String, String>{};
      for (final entry in cells.entries) {
        if (!columnIds.contains(entry.key)) return null;
        final value = entry.value;
        if (value == null) {
          normalized[entry.key] = '';
        } else if (value is String || value is num || value is bool) {
          normalized[entry.key] = value.toString();
        } else {
          return null;
        }
      }
      rows.add(TableRowData(id: id, cells: normalized));
    }

    return TableDocument(columns: columns, rows: rows);
  }

  static Future<TableDocument?> read(String path) async {
    try {
      final content = await File(path).readAsString(encoding: utf8);
      return tryParse(jsonDecode(content));
    } catch (_) {
      return null;
    }
  }

  Map<String, Object> toJson() => {
        'type': tableDocumentType,
        'version': tableDocumentVersion,
        'columns': columns.map((c) => c.toJson()).toList(),
        'rows': rows.map((r) => r.toJson()).toList(),
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

Future<bool> isCompatibleTableJson(String path) async =>
    await TableDocument.read(path) != null;
