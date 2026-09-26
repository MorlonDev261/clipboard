import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/copy_button.dart';
import '../../../shared/enums/enums.dart';
import '../application/assets_providers.dart';

/// Screen to create (or edit) a reusable text asset.
class CreateTextScreen extends ConsumerStatefulWidget {
  const CreateTextScreen({required this.folderId, this.assetId, super.key});

  final String folderId;

  /// When non-null, the screen edits an existing text asset.
  final String? assetId;

  @override
  ConsumerState<CreateTextScreen> createState() => _CreateTextScreenState();
}

class _CreateTextScreenState extends ConsumerState<CreateTextScreen> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  AssetStatus _status = AssetStatus.draft;
  bool _loaded = false;
  bool _saving = false;

  bool get _isEditing => widget.assetId != null;

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _save(AppStrings strings) async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _snack(strings.textEmptyError);
      return;
    }
    setState(() => _saving = true);
    try {
      final controller = ref.read(assetsControllerProvider);
      final title = _titleController.text.trim();
      if (_isEditing) {
        await controller.updateText(
          widget.assetId!,
          text: text,
          title: title.isEmpty ? null : title,
          status: _status,
        );
      } else {
        await controller.createText(
          folderId: widget.folderId,
          text: text,
          title: title.isEmpty ? null : title,
          status: _status,
        );
      }
      if (!mounted) return;
      _snack(strings.textSaved);
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

    // Pre-fill fields once when editing.
    if (_isEditing && !_loaded) {
      final asset = ref.watch(assetProvider(widget.assetId!)).valueOrNull;
      if (asset != null) {
        _titleController.text = asset.title ?? '';
        _textController.text = asset.textContent ?? '';
        _status = asset.status == AssetStatus.ready
            ? AssetStatus.ready
            : AssetStatus.draft;
        _loaded = true;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? strings.editTextTitle : strings.createTextTitle),
        actions: [
          CopyButton(
            text: _textController.text,
            label: strings.copy,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: strings.titleOptionalLabel),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _textController,
                decoration: InputDecoration(
                  labelText: strings.textLabel,
                  alignLabelWithHint: true,
                ),
                minLines: 6,
                maxLines: 16,
                onChanged: (_) => setState(() {}), // keep CopyButton in sync
              ),
              const SizedBox(height: 16),
              Text(strings.statusLabel,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<AssetStatus>(
                segments: [
                  ButtonSegment(
                    value: AssetStatus.draft,
                    label: Text(strings.statusDraft),
                    icon: const Icon(Icons.edit_note),
                  ),
                  ButtonSegment(
                    value: AssetStatus.ready,
                    label: Text(strings.statusReady),
                    icon: const Icon(Icons.check_circle_outline),
                  ),
                ],
                selected: {_status},
                onSelectionChanged: (s) => setState(() => _status = s.first),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
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
            ],
          ),
        ),
      ),
    );
  }
}
