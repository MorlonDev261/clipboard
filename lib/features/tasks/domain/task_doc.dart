class ChecklistItem {
  ChecklistItem({required this.id, this.text = '', this.done = false});

  final String id;
  String text;
  bool done;

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'done': done};

  static ChecklistItem? tryFromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String) return null;
    return ChecklistItem(
      id: raw['id'] as String,
      text: raw['text'] is String ? raw['text'] as String : '',
      done: raw['done'] == true,
    );
  }
}

enum TaskBlockKind { text, checklist }

/// A block of a task: free text, or a titled checklist.
class TaskBlock {
  TaskBlock({
    required this.id,
    required this.kind,
    this.text = '',
    List<ChecklistItem>? items,
  }) : items = items ?? [];

  final String id;
  final TaskBlockKind kind;

  /// Body of a text block, or the title of a checklist.
  String text;
  final List<ChecklistItem> items;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': kind.name,
        'text': text,
        if (kind == TaskBlockKind.checklist)
          'items': [for (final i in items) i.toJson()],
      };

  static TaskBlock? tryFromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String) return null;
    final kind = raw['type'] == TaskBlockKind.checklist.name
        ? TaskBlockKind.checklist
        : TaskBlockKind.text;
    final rawItems = raw['items'];
    return TaskBlock(
      id: raw['id'] as String,
      kind: kind,
      text: raw['text'] is String ? raw['text'] as String : '',
      items: [
        if (rawItems is List)
          for (final i in rawItems)
            if (ChecklistItem.tryFromJson(i) case final item?) item,
      ],
    );
  }
}

/// One task = one JSON file (`<root>/.clipboard/tasks/<id>.json`).
class TaskDoc {
  TaskDoc({
    required this.id,
    this.title = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    List<TaskBlock>? blocks,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        blocks = blocks ?? [];

  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<TaskBlock> blocks;

  int get totalItems => blocks.fold(0, (s, b) => s + b.items.length);
  int get doneItems =>
      blocks.fold(0, (s, b) => s + b.items.where((i) => i.done).length);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'blocks': [for (final b in blocks) b.toJson()],
      };

  static TaskDoc? tryFromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String) return null;
    final rawBlocks = raw['blocks'];
    return TaskDoc(
      id: raw['id'] as String,
      title: raw['title'] is String ? raw['title'] as String : '',
      createdAt: DateTime.tryParse('${raw['createdAt']}'),
      updatedAt: DateTime.tryParse('${raw['updatedAt']}'),
      blocks: [
        if (rawBlocks is List)
          for (final b in rawBlocks)
            if (TaskBlock.tryFromJson(b) case final block?) block,
      ],
    );
  }
}
