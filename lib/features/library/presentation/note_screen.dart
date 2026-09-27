import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:pasteboard/pasteboard.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/constants/app_constants.dart';
import '../../../core/formatting/list_format.dart';
import '../../../core/formatting/unicode_styler.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/picker/app_file_picker.dart';
import '../../../core/picker/pick_mode.dart';
import '../../../core/widgets/copy_menu_button.dart';
import '../application/library_providers.dart';
import 'widgets/chat_preview_dialog.dart';
import 'widgets/formatting_toolbar.dart';

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
  final _contentFocus = FocusNode();
  bool _loading = false;
  bool _saving = false;

  /// View mode (blocks with per-block copy) vs. edit mode. Existing notes open
  /// in view mode; a brand-new note opens straight in edit mode.
  bool _editing = false;

  /// Attachment image tags (`![name](link)`) kept OUT of the editor text so they
  /// never clutter the content. They are stored back into the `.md` on save, so
  /// stats, the media filter and the note↔image association keep working.
  final List<String> _imageTags = [];

  /// Pending "active" style: what freshly-typed text is converted into when no
  /// selection is targeted (like clicking Bold then typing).
  InlineStyle _activeStyle = InlineStyle.none;
  String _prevText = '';
  bool _applyingStyle = false;
  static const _styler = UnicodeStyler();

  bool get _isEditing => widget.existingPath != null;

  /// The folder the note lives in (known even for a not-yet-saved note).
  String get _dir => widget.newDir ?? p.dirname(widget.existingPath!);

  static final _imageLinkRegExp = RegExp(r'!\[[^\]]*\]\(([^)]+)\)');

  @override
  void initState() {
    super.initState();
    // Refresh the live preview / copy content on any edit, including the
    // programmatic edits made by the formatting toolbar.
    _contentController.addListener(_onContentChanged);
    _editing = widget.existingPath == null; // new note → edit; existing → view
    if (_isEditing) {
      _titleController.text = p.basenameWithoutExtension(widget.existingPath!);
      _loadContent();
    }
  }

  void _onContentChanged() {
    if (_applyingStyle) return;
    final value = _contentController.value;
    final newText = value.text;

    // Convert freshly-typed characters into the active style. Skip while an IME
    // composition is in progress to avoid disrupting it.
    if (value.composing.isCollapsed) {
      final insertion = _extractInsertion(_prevText, newText);
      if (insertion != null) {
        final (start, inserted) = insertion;
        // Enter inside a list → continue it, or exit on an empty item.
        if (inserted == '\n' && _handleListNewline(newText, start)) {
          return;
        }
        // Active style → convert the freshly-typed characters.
        final styled = _activeStyle.isEmpty
            ? inserted
            : _styler.transform(_styler.plainify(inserted), _activeStyle);
        if (styled != inserted) {
          final replaced =
              newText.replaceRange(start, start + inserted.length, styled);
          _applyingStyle = true;
          _contentController.value = TextEditingValue(
            text: replaced,
            selection: TextSelection.collapsed(offset: start + styled.length),
            composing: TextRange.empty,
          );
          _applyingStyle = false;
          _prevText = replaced;
          if (mounted) setState(() {});
          return;
        }
      }
    }
    _prevText = newText;
    if (mounted) setState(() {});
  }

  /// Returns the (start, text) of a single contiguous insertion between [oldT]
  /// and [newT], or null if the change is not a plain insertion.
  (int, String)? _extractInsertion(String oldT, String newT) {
    if (newT.length <= oldT.length) return null;
    var prefix = 0;
    final min = oldT.length;
    while (prefix < min && oldT.codeUnitAt(prefix) == newT.codeUnitAt(prefix)) {
      prefix++;
    }
    final insertedLen = newT.length - oldT.length;
    final inserted = newT.substring(prefix, prefix + insertedLen);
    // Verify the rest matches (pure insertion, not a replacement).
    if (oldT ==
        newT.substring(0, prefix) + newT.substring(prefix + insertedLen)) {
      return (prefix, inserted);
    }
    return null;
  }

  /// Handles Enter pressed on a list line: continue the list with the next
  /// prefix, or — if the current item is empty — exit the list. Returns true
  /// when it changed the text.
  bool _handleListNewline(String newText, int newlinePos) {
    final before = newText.substring(0, newlinePos);
    final lineStart = before.lastIndexOf('\n') + 1;
    final curLine = before.substring(lineStart);

    final bullet = ListFormat.bulletRe.firstMatch(curLine);
    final numbered = ListFormat.numberedRe.firstMatch(curLine);
    if (bullet == null && numbered == null) return false;

    final content =
        (bullet != null ? bullet.group(2) : numbered!.group(3)) ?? '';

    final String replaced;
    final int cursor;
    if (content.trim().isEmpty) {
      // Empty item + Enter → leave the list: drop the prefix and the newline.
      replaced =
          newText.substring(0, lineStart) + newText.substring(newlinePos + 1);
      cursor = lineStart;
    } else {
      // Continue the list on the new line.
      final prefix = bullet != null
          ? ListFormat.bullet
          : ListFormat.numbered((int.tryParse(numbered!.group(2)!) ?? 1) + 1);
      replaced = newText.substring(0, newlinePos + 1) +
          prefix +
          newText.substring(newlinePos + 1);
      cursor = newlinePos + 1 + prefix.length;
    }

    _applyingStyle = true;
    _contentController.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
    _applyingStyle = false;
    _prevText = replaced;
    if (mounted) setState(() {});
    return true;
  }

  Future<void> _loadContent() async {
    setState(() => _loading = true);
    try {
      final raw = await ref
          .read(libraryControllerProvider)
          .readNote(widget.existingPath!);
      final (body, tags) = _splitBodyAndImages(raw);
      _imageTags
        ..clear()
        ..addAll(tags);
      _contentController.text = body;
      _prevText = body;
    } catch (_) {
      // leave empty on error
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Separates the editable body from the attachment image tags. Lines that are
  /// only an image tag are dropped from the body; inline tags are lifted out too.
  (String, List<String>) _splitBodyAndImages(String raw) {
    final tags = <String>[];
    final bodyLines = <String>[];
    for (final line in raw.split('\n')) {
      final matches = _imageLinkRegExp.allMatches(line).toList();
      if (matches.isEmpty) {
        bodyLines.add(line);
        continue;
      }
      for (final m in matches) {
        tags.add(m.group(0)!);
      }
      final stripped = line.replaceAll(_imageLinkRegExp, '').trim();
      if (stripped.isNotEmpty) bodyLines.add(stripped);
    }
    return (bodyLines.join('\n').trimRight(), tags);
  }

  /// Rebuilds the full `.md` content: the body followed by the attachment tags.
  String _composeContent() {
    final body = _contentController.text.trimRight();
    if (_imageTags.isEmpty) return body;
    final block = _imageTags.join('\n');
    return body.isEmpty ? block : '$body\n\n$block';
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  /// Absolute paths of the attached images (from the separated tag list).
  List<String> _attachedImages() {
    final out = <String>[];
    for (final tag in _imageTags) {
      final m = _imageLinkRegExp.firstMatch(tag);
      if (m == null) continue;
      final link = Uri.decodeFull(m.group(1)!.trim());
      final abs = p.isAbsolute(link) ? link : p.normalize(p.join(_dir, link));
      out.add(abs);
    }
    return out;
  }

  Future<void> _attachPhotos(AppStrings strings) async {
    final paths = await AppFilePicker.pick(
      context,
      mode: PickMode.imageFiles,
      title: strings.attachPhoto,
    );
    if (paths.isEmpty) return;
    final controller = ref.read(libraryControllerProvider);
    final newTags = <String>[];
    for (final src in paths) {
      try {
        final link = await controller.attachImage(_dir, src);
        final name = p.basenameWithoutExtension(src);
        // Kept separate from the editor text; merged into the .md only on save.
        newTags.add('![$name](${Uri.encodeFull(link)})');
      } catch (_) {
        // skip failed attachment
      }
    }
    if (newTags.isEmpty) return;
    setState(() => _imageTags.addAll(newTags));
    if (mounted) _snack(strings.photosAttached(newTags.length));
  }

  void _viewImage(String path) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.file(File(path),
              errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Icon(Icons.broken_image_outlined))),
        ),
      ),
    );
  }

  Future<void> _save(AppStrings strings) async {
    final content = _composeContent();
    if (content.trim().isEmpty) {
      _snack(strings.emptyNoteError);
      return;
    }
    setState(() => _saving = true);
    final controller = ref.read(libraryControllerProvider);
    var renamed = false;
    try {
      if (_isEditing) {
        final path = widget.existingPath!;
        final parent = p.dirname(path);
        await controller.saveNote(path, content);
        final newTitle = _titleController.text.trim();
        if (newTitle.isNotEmpty &&
            newTitle != p.basenameWithoutExtension(path)) {
          await controller.rename(path, newTitle, parentDir: parent);
          renamed = true;
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
      // Existing note (unchanged path) → back to view mode; new or renamed
      // note (path changed) → leave the screen.
      if (_isEditing && !renamed) {
        setState(() {
          _saving = false;
          _editing = false;
        });
      } else {
        context.pop();
      }
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

  /// Splits the note body into blocks separated by blank lines.
  List<String> _blocks(String text) => text
      .split(RegExp(r'\n[ \t]*\n'))
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();

  Future<void> _copyText(String text, AppStrings strings) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) _snack(strings.copiedToClipboard);
    } catch (_) {
      if (mounted) _snack(strings.copyFailed);
    }
  }

  Future<void> _copyImage(String path, AppStrings strings) async {
    try {
      final bytes = await File(path).readAsBytes();
      await Pasteboard.writeImage(bytes);
      if (mounted) _snack(strings.copiedToClipboard);
    } catch (_) {
      if (mounted) _snack(strings.copyFailed);
    }
  }

  /// Opens the system share sheet with the caption and attached images.
  Future<void> _share(AppStrings strings, List<String> images) async {
    final text = _contentController.text;
    if (text.trim().isEmpty && images.isEmpty) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text.isEmpty ? null : text,
          files: images.map((path) => XFile(path)).toList(),
        ),
      );
    } catch (_) {
      if (mounted) _snack(strings.genericError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final images = _attachedImages();
    final isEmpty =
        _contentController.text.trim().isEmpty && _imageTags.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle(strings)),
        actions: [
          if (!_editing)
            IconButton(
              tooltip: strings.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
            ),
          IconButton(
            tooltip: strings.preview,
            icon: const Icon(Icons.visibility_outlined),
            onPressed: isEmpty
                ? null
                : () => ChatPreviewDialog.show(
                      context,
                      markdown: _contentController.text,
                      imagePaths: images,
                    ),
          ),
          if (_editing)
            IconButton(
              tooltip: strings.attachPhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: () => _attachPhotos(strings),
            ),
          IconButton(
            tooltip: strings.share,
            icon: const Icon(Icons.ios_share),
            onPressed: isEmpty ? null : () => _share(strings, images),
          ),
          CopyMenuButton(
            content: _contentController.text,
            imagePaths: images,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _editing
                    ? _buildEdit(strings, images)
                    : _buildView(strings, images),
              ),
            ),
    );
  }

  String _appBarTitle(AppStrings strings) {
    if (_editing) {
      return _isEditing ? strings.editNoteTitle : strings.newNoteTitle;
    }
    return _isEditing
        ? p.basenameWithoutExtension(widget.existingPath!)
        : strings.newNoteTitle;
  }

  // --- View mode: read-only blocks, each copyable ----------------------------

  Widget _buildView(AppStrings strings, List<String> images) {
    final blocks = _blocks(_contentController.text);
    return ListView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      children: [
        Text(
          _titleController.text.isEmpty
              ? strings.newNoteTitle
              : _titleController.text,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        if (blocks.isEmpty && images.isEmpty)
          Text(strings.noContents,
              style: Theme.of(context).textTheme.bodyMedium),
        for (final block in blocks) ...[
          _CopyableBlock(
            text: block,
            onCopy: () => _copyText(block, strings),
            copyTooltip: strings.copy,
          ),
          const SizedBox(height: 12),
        ],
        if (images.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(strings.attachments,
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final path in images) ...[
            _CopyableImage(
              path: path,
              onView: () => _viewImage(path),
              onCopy: () => _copyImage(path, strings),
              copyTooltip: strings.copy,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  // --- Edit mode -------------------------------------------------------------

  Widget _buildEdit(AppStrings strings, List<String> images) {
    return ListView(
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
        const SizedBox(height: 8),
        FormattingToolbar(
          controller: _contentController,
          focusNode: _contentFocus,
          activeStyle: _activeStyle,
          onActiveStyleChanged: (s) => setState(() => _activeStyle = s),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _contentController,
          focusNode: _contentFocus,
          style: const TextStyle(
            fontFamily: AppConstants.noteFontFamily,
            fontFamilyFallback: AppConstants.noteFontFallback,
            fontSize: 16,
            height: 1.4,
          ),
          decoration: InputDecoration(
            labelText: strings.noteContent,
            alignLabelWithHint: true,
          ),
          keyboardType: TextInputType.multiline,
          // Grow with the content instead of scrolling internally: the page
          // (the outer ListView) becomes the single scroll surface, so a drag
          // anywhere — including over this field — scrolls the whole page.
          minLines: 8,
          maxLines: null,
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
                        child: CircularProgressIndicator(strokeWidth: 2),
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
        if (images.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(strings.attachments,
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _AttachmentStrip(images: images, onTap: _viewImage),
        ],
      ],
    );
  }
}

/// A read-only text block with a copy button (view mode).
class _CopyableBlock extends StatelessWidget {
  const _CopyableBlock({
    required this.text,
    required this.onCopy,
    required this.copyTooltip,
  });

  final String text;
  final VoidCallback onCopy;
  final String copyTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              text,
              style: const TextStyle(
                fontFamily: AppConstants.noteFontFamily,
                fontFamilyFallback: AppConstants.noteFontFallback,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: copyTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

/// An attachment thumbnail with a copy button (view mode).
class _CopyableImage extends StatelessWidget {
  const _CopyableImage({
    required this.path,
    required this.onView,
    required this.onCopy,
    required this.copyTooltip,
  });

  final String path;
  final VoidCallback onView;
  final VoidCallback onCopy;
  final String copyTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onView,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(path),
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                cacheWidth: 150,
                errorBuilder: (_, __, ___) => Container(
                  width: 72,
                  height: 72,
                  color: scheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              p.basename(path),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: copyTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: onCopy,
          ),
        ],
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
