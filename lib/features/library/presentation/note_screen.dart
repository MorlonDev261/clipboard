import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../app/constants/app_constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/copy_button.dart';
import '../application/library_providers.dart';

/// Creates or edits a Markdown note (a real `.md` file on disk).
///
/// Pass [existingPath] to edit an existing note, or [newDir] to create one.
class NoteScreen extends ConsumerStatefulWidget {
  const NoteScreen({this.existingPath, this.newDir, super.key})
      : assert(existingPath != null || newDir != null);

  final String? existingPath;
  final String? newDir;

  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _loading = false;
  bool _saving = false;

  bool get _isEditing => widget.existingPath != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = p.basenameWithoutExtension(widget.existingPath!);
      _loadContent();
    }
  }

  Future<void> _loadContent() async {
    setState(() => _loading = true);
    try {
      final content =
          await ref.read(libraryControllerProvider).readNote(widget.existingPath!);
      _contentController.text = content;
    } catch (_) {
      // leave empty on error
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save(AppStrings strings) async {
    final content = _contentController.text;
    if (content.trim().isEmpty) {
      _snack(strings.emptyNoteError);
      return;
    }
    setState(() => _saving = true);
    final controller = ref.read(libraryControllerProvider);
    try {
      if (_isEditing) {
        final path = widget.existingPath!;
        final parent = p.dirname(path);
        await controller.saveNote(path, content);
        final newTitle = _titleController.text.trim();
        if (newTitle.isNotEmpty &&
            newTitle != p.basenameWithoutExtension(path)) {
          await controller.rename(path, newTitle, parentDir: parent);
        } else {
          ref.invalidate(directoryProvider(parent));
        }
      } else {
        await controller.createNote(
          widget.newDir!,
          title: _titleController.text.trim(),
          content: content,
        );
      }
      if (!mounted) return;
      _snack(strings.noteSaved);
      context.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(strings.genericError);
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? strings.editNoteTitle : strings.newNoteTitle),
        actions: [
          CopyButton(text: _contentController.text, label: strings.copy),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: strings.noteTitle,
                        hintText: strings.noteTitleHint,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        labelText: strings.noteContent,
                        alignLabelWithHint: true,
                      ),
                      minLines: 8,
                      maxLines: 24,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : () => _save(strings),
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(strings.save),
                          ),
                        ),
                        const SizedBox(width: 12),
                        CopyButton(
                          text: _contentController.text,
                          label: strings.copyContent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
