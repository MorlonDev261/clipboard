import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../app/constants/app_constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/copy_button.dart';
import '../application/library_providers.dart';

/// Creates or edits a Markdown note (a real `.md` file on disk), with photo
/// attachments copied next to the note and embedded as Markdown image links.
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

  /// The folder the note lives in (known even for a not-yet-saved note).
  String get _dir =>
      widget.newDir ?? p.dirname(widget.existingPath!);

  static final _imageLinkRegExp = RegExp(r'!\[[^\]]*\]\(([^)]+)\)');

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
      _contentController.text =
          await ref.read(libraryControllerProvider).readNote(widget.existingPath!);
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

  /// Absolute paths of the images referenced in the current content.
  List<String> _attachedImages() {
    final out = <String>[];
    for (final m in _imageLinkRegExp.allMatches(_contentController.text)) {
      final link = Uri.decodeFull(m.group(1)!.trim());
      final abs = p.isAbsolute(link) ? link : p.normalize(p.join(_dir, link));
      out.add(abs);
    }
    return out;
  }

  Future<void> _attachPhotos(AppStrings strings) async {
    final result = await FilePicker.platform
        .pickFiles(allowMultiple: true, type: FileType.image);
    if (result == null) return;
    final paths = result.paths.whereType<String>().toList();
    if (paths.isEmpty) return;
    final controller = ref.read(libraryControllerProvider);
    final buffer = StringBuffer(_contentController.text);
    for (final src in paths) {
      try {
        final link = await controller.attachImage(_dir, src);
        final name = p.basenameWithoutExtension(src);
        if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
          buffer.write('\n');
        }
        buffer.write('\n![$name](${Uri.encodeFull(link)})\n');
      } catch (_) {
        // skip failed attachment
      }
    }
    setState(() => _contentController.text = buffer.toString());
    if (mounted) _snack(strings.photosAttached(paths.length));
  }

  void _viewImage(String path) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.file(File(path),
              errorBuilder: (_, __, ___) =>
                  const Padding(padding: EdgeInsets.all(24), child: Icon(Icons.broken_image_outlined))),
        ),
      ),
    );
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
    final images = _attachedImages();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? strings.editNoteTitle : strings.newNoteTitle),
        actions: [
          IconButton(
            tooltip: strings.attachPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: () => _attachPhotos(strings),
          ),
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
                    if (images.isNotEmpty) ...[
                      _AttachmentStrip(images: images, onTap: _viewImage),
                      const SizedBox(height: 16),
                    ],
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
                        OutlinedButton.icon(
                          onPressed: () => _attachPhotos(strings),
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(strings.attachPhoto),
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

class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({required this.images, required this.onTap});

  final List<String> images;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final path = images[i];
          return GestureDetector(
            onTap: () => onTap(path),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(path),
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                cacheWidth: 200,
                errorBuilder: (_, __, ___) => Container(
                  width: 96,
                  height: 96,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
