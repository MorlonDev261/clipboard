import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/edit_mode_provider.dart';
import '../application/task_providers.dart';
import '../data/task_store.dart';
import '../domain/task_doc.dart';

/// Edits one task: a title plus any number of text blocks and checklists.
/// Every change is saved (debounced) to the task's JSON file.
class TaskEditorScreen extends ConsumerStatefulWidget {
  const TaskEditorScreen({required this.taskId, super.key});

  final String taskId;

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  static const _uuid = Uuid();

  TaskStore? _store;
  TaskDoc? _task;
  bool _loaded = false;
  bool _dirty = false;
  Timer? _debounce;
  final _titleController = TextEditingController();
  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _store = ref.read(taskStoreProvider);
    _load();
  }

  Future<void> _load() async {
    final task = await _store?.load(widget.taskId);
    if (!mounted) return;
    setState(() {
      _task = task;
      _loaded = true;
      _titleController.text = task?.title ?? '';
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_dirty) _flush();
    _titleController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String id, String initial) =>
      _controllers.putIfAbsent(id, () => TextEditingController(text: initial));

  void _changed() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _flush);
  }

  void _flush() {
    final task = _task;
    if (task == null) return;
    _dirty = false;
    _store?.save(task);
  }

  void _mutate(VoidCallback change) {
    setState(change);
    _changed();
  }

  void _addBlock(TaskBlockKind kind) => _mutate(() {
        _task!.blocks.add(TaskBlock(
          id: _uuid.v4(),
          kind: kind,
          items: kind == TaskBlockKind.checklist
              ? [ChecklistItem(id: _uuid.v4())]
              : null,
        ));
      });

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final task = _task;
    final editing = ref.watch(editModeProvider);

    void back() => context.canPop() ? context.pop() : context.go('/task');

    if (_loaded && task == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: back)),
        body: Center(child: Text(strings.noTasks)),
      );
    }

    final total = task?.totalItems ?? 0;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: back),
        title: Text(strings.tasks),
        actions: const [EditModeButton()],
        bottom: total == 0
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: task!.doneItems / total,
                ),
              ),
      ),
      body: task == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                TextField(
                  controller: _titleController,
                  style: Theme.of(context).textTheme.headlineSmall,
                  readOnly: !editing,
                  decoration: InputDecoration(
                    hintText: strings.taskTitle,
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: InputBorder.none,
                  ),
                  onChanged: (v) {
                    task.title = v;
                    _changed();
                  },
                ),
                const SizedBox(height: 8),
                for (final block in task.blocks)
                  block.kind == TaskBlockKind.text
                      ? _TextBlockCard(
                          key: ValueKey(block.id),
                          strings: strings,
                          editing: editing,
                          controller: _controller(block.id, block.text),
                          onChanged: (v) {
                            block.text = v;
                            _changed();
                          },
                          onDelete: () =>
                              _mutate(() => task.blocks.remove(block)),
                        )
                      : _ChecklistBlockCard(
                          key: ValueKey(block.id),
                          strings: strings,
                          editing: editing,
                          block: block,
                          controller: _controller,
                          onChanged: _changed,
                          mutate: _mutate,
                          newItemId: _uuid.v4,
                          onDelete: () =>
                              _mutate(() => task.blocks.remove(block)),
                        ),
                const SizedBox(height: 8),
                if (editing)
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _addBlock(TaskBlockKind.text),
                        icon: const Icon(Icons.notes),
                        label: Text(strings.addTextBlock),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _addBlock(TaskBlockKind.checklist),
                        icon: const Icon(Icons.checklist),
                        label: Text(strings.addChecklist),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _TextBlockCard extends StatelessWidget {
  const _TextBlockCard({
    required this.strings,
    required this.editing,
    required this.controller,
    required this.onChanged,
    required this.onDelete,
    super.key,
  });

  final AppStrings strings;
  final bool editing;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Card(
      color: bg,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                readOnly: !editing,
                minLines: 2,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: strings.textHint,
                  filled: true,
                  fillColor: bg,
                  border: InputBorder.none,
                ),
                onChanged: onChanged,
              ),
            ),
            if (editing)
              IconButton(
                tooltip: strings.deleteBlock,
                icon: const Icon(Icons.close),
                onPressed: onDelete,
              )
            else
              const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _ChecklistBlockCard extends StatelessWidget {
  const _ChecklistBlockCard({
    required this.strings,
    required this.editing,
    required this.block,
    required this.controller,
    required this.onChanged,
    required this.mutate,
    required this.newItemId,
    required this.onDelete,
    super.key,
  });

  final AppStrings strings;
  final bool editing;
  final TaskBlock block;
  final TextEditingController Function(String id, String initial) controller;
  final VoidCallback onChanged;
  final void Function(VoidCallback change) mutate;
  final String Function() newItemId;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    return Card(
      color: bg,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller(block.id, block.text),
                    readOnly: !editing,
                    style: theme.textTheme.titleMedium,
                    decoration: InputDecoration(
                      hintText: strings.checklistTitleHint,
                      filled: true,
                      fillColor: bg,
                      border: InputBorder.none,
                    ),
                    onChanged: (v) {
                      block.text = v;
                      onChanged();
                    },
                  ),
                ),
                if (editing)
                  IconButton(
                    tooltip: strings.deleteBlock,
                    icon: const Icon(Icons.close),
                    onPressed: onDelete,
                  )
                else
                  const SizedBox(height: 48),
              ],
            ),
            for (final item in block.items)
              Row(
                key: ValueKey(item.id),
                children: [
                  Checkbox(
                    value: item.done,
                    onChanged: (v) => mutate(() => item.done = v ?? false),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller(item.id, item.text),
                      readOnly: !editing,
                      decoration: InputDecoration(
                        hintText: strings.itemHint,
                        filled: true,
                        fillColor: bg,
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: item.done
                          ? TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: theme.colorScheme.onSurfaceVariant,
                            )
                          : null,
                      onChanged: (v) {
                        item.text = v;
                        onChanged();
                      },
                    ),
                  ),
                  if (editing)
                    IconButton(
                      iconSize: 18,
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => mutate(() => block.items.remove(item)),
                    ),
                ],
              ),
            if (editing)
              TextButton.icon(
                onPressed: () => mutate(
                    () => block.items.add(ChecklistItem(id: newItemId()))),
                icon: const Icon(Icons.add),
                label: Text(strings.addItem),
              ),
          ],
        ),
      ),
    );
  }
}
