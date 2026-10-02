import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/l10n/app_strings.dart';
import '../../../core/picker/app_file_picker.dart';
import '../../../core/picker/pick_mode.dart';
import '../../library/domain/library_entry.dart';
import '../../library/presentation/widgets/video_preview.dart';
import '../application/metadata_cleaner_service.dart';
import '../domain/clean_report.dart';
import 'clean_report_card.dart';

/// The "Deganeo" tool: pick a photo/video, strip its metadata, verify the
/// result with an independent re-scan, then save / replace / discard it.
class CleanerPage extends ConsumerStatefulWidget {
  const CleanerPage({super.key});

  @override
  ConsumerState<CleanerPage> createState() => _CleanerPageState();
}

class _CleanerPageState extends ConsumerState<CleanerPage> {
  final _cleaner = const MetadataCleanerService();
  String? _sourcePath;
  String? _cleanPath;
  CleanReport? _cleanResult;
  bool _dragging = false;
  bool _cleaning = false;
  bool _detailsOpen = false;

  @override
  void initState() {
    super.initState();
    // Housekeeping: cleaned copies orphaned by a killed app.
    unawaited(_cleaner.purgeStaleCopies());
  }

  @override
  void dispose() {
    _deleteTempSync(_cleanPath);
    super.dispose();
  }

  Future<void> _pick() async {
    final strings = ref.read(appStringsProvider);
    final paths = await AppFilePicker.pick(
      context,
      mode: PickMode.mediaFiles,
      title: strings.selectMediaTitle,
      allowMultiple: false,
    );
    if (paths.isNotEmpty) _setSource(paths.first);
  }

  void _setSource(String path) {
    _deleteTempSync(_cleanPath);
    setState(() {
      _sourcePath = path;
      _cleanPath = null;
      _cleanResult = null;
      _detailsOpen = false;
    });
  }

  Future<void> _clean() async {
    final source = _sourcePath;
    if (source == null) return;
    final strings = ref.read(appStringsProvider);
    setState(() => _cleaning = true);
    try {
      final started = DateTime.now();
      final report = await _cleaner.clean(source);
      final elapsed = DateTime.now().difference(started);
      const minimum = Duration(milliseconds: 1500);
      if (elapsed < minimum) {
        await Future<void>.delayed(minimum - elapsed);
      }
      if (!mounted) {
        await _deleteTemp(report.outputPath);
        return;
      }
      setState(() {
        _cleanPath = report.outputPath;
        _cleanResult = report;
        _cleaning = false;
        _detailsOpen = !report.isClean;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cleaning = false);
      _snack(strings.genericError);
    }
  }

  /// Android / iOS savers need the bytes in memory; refuse files too large for
  /// a phone instead of crashing the app.
  static const _maxMobileSaveBytes = 150 * 1024 * 1024;

  Future<void> _download() async {
    final clean = _cleanPath;
    final source = _sourcePath;
    if (clean == null || source == null) return;
    final strings = ref.read(appStringsProvider);
    try {
      final mobile = Platform.isAndroid || Platform.isIOS;
      if (mobile && await File(clean).length() > _maxMobileSaveBytes) {
        if (mounted) _snack(strings.genericError);
        return;
      }
      final target = await FilePicker.saveFile(
        dialogTitle: strings.download,
        // The cleaned copy keeps the extension of its *real* format (a ".jpg"
        // that was a PNG is saved as ".png").
        fileName:
            '${p.basenameWithoutExtension(source)}_clean${p.extension(clean)}',
        bytes: mobile ? await File(clean).readAsBytes() : null,
      );
      if (target == null) return;
      if (!mobile) await File(clean).copy(target);
      await _eraseCleanCopy(showSnack: false);
      if (mounted) _snack(strings.fileDownloaded);
    } catch (_) {
      if (mounted) _snack(strings.genericError);
    }
  }

  Future<void> _replace() async {
    final clean = _cleanPath;
    final source = _sourcePath;
    if (clean == null || source == null) return;
    final strings = ref.read(appStringsProvider);
    try {
      // Copy next to the original, then swap with one rename: a failure halfway
      // (disk full, app killed) must never leave the user's original truncated.
      final tmp = File('$source.influencor-tmp');
      await File(clean).copy(tmp.path);
      await tmp.rename(source);
      await _deleteTemp(clean);
      if (!mounted) return;
      _snack(strings.fileReplaced);
      _setSource(source);
    } catch (_) {
      if (mounted) _snack(strings.genericError);
    }
  }

  Future<void> _eraseCleanCopy({bool showSnack = true}) async {
    final clean = _cleanPath;
    if (clean == null) return;
    final strings = ref.read(appStringsProvider);
    await _deleteTemp(clean);
    if (!mounted) return;
    setState(() {
      _cleanPath = null;
      _cleanResult = null;
      _detailsOpen = false;
    });
    if (showSnack) _snack(strings.cleanCopyErased);
  }

  Future<void> _deleteTemp(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort cleanup: never block the user's flow if temp deletion fails.
    }
  }

  void _deleteTempSync(String? path) {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Best-effort cleanup during state changes/dispose.
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
    final source = _sourcePath;
    final clean = _cleanPath;
    final cleanResult = _cleanResult;
    final shown = clean ?? source;

    return DropTarget(
      key: const ValueKey('deganeo-page'),
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        final path = detail.files
            .map((file) => file.path)
            .where((path) => path.isNotEmpty)
            .where(_isMediaPath)
            .cast<String?>()
            .firstWhere((path) => path != null, orElse: () => null);
        if (path != null) _setSource(path);
      },
      child: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (shown == null) ...[
                      _UploadPanel(onPick: _pick),
                      const SizedBox(height: 12),
                      _WatermarkNotice(
                          message: strings.visibleWatermarkNotRemoved),
                    ] else ...[
                      _MediaPreview(
                        path: shown,
                        cleaning: _cleaning,
                        cleaned: clean != null,
                      ),
                      const SizedBox(height: 16),
                      if (cleanResult == null)
                        FilledButton.icon(
                          onPressed: _cleaning ? null : _clean,
                          icon: _cleaning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_fix_high_outlined),
                          label: Text(strings.cleanMediaCta),
                        )
                      else
                        Column(
                          children: [
                            CleanReportCard(
                              report: cleanResult,
                              expanded: _detailsOpen,
                              onToggle: () => setState(
                                () => _detailsOpen = !_detailsOpen,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (clean == null)
                              OutlinedButton.icon(
                                onPressed: _pick,
                                icon: const Icon(Icons.folder_open_outlined),
                                label: Text(strings.chooseAnotherFile),
                              )
                            else
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  FilledButton.icon(
                                    onPressed: _download,
                                    icon: const Icon(Icons.download_outlined),
                                    label: Text(strings.download),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _replace,
                                    icon:
                                        const Icon(Icons.find_replace_outlined),
                                    label: Text(strings.replace),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _eraseCleanCopy(),
                                    icon:
                                        const Icon(Icons.delete_sweep_outlined),
                                    label: Text(strings.eraseCleanCopy),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      _WatermarkNotice(
                          message: strings.visibleWatermarkNotRemoved),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_dragging)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                ),
                child: Center(
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(strings.dropToImport),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isMediaPath(String path) {
    final kind = kindForFile(path);
    return kind == EntryKind.image ||
        kind == EntryKind.video ||
        isCleanableDocument(path);
  }
}

class _WatermarkNotice extends StatelessWidget {
  const _WatermarkNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadPanel extends ConsumerWidget {
  const _UploadPanel({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPick,
      child: Container(
        constraints: const BoxConstraints(minHeight: 260),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              strings.uploadMedia,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(strings.dropToImport),
          ],
        ),
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({
    required this.path,
    required this.cleaning,
    required this.cleaned,
  });

  final String path;
  final bool cleaning;
  final bool cleaned;

  @override
  Widget build(BuildContext context) {
    final kind = kindForFile(path);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420, maxWidth: 640),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                cleaned ? Border.all(color: scheme.primary, width: 2) : null,
            boxShadow: cleaned
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: cleaning ? 2.5 : 0,
                        sigmaY: cleaning ? 2.5 : 0,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: kind == EntryKind.video
                            ? VideoPreview(key: ValueKey(path), path: path)
                            : canRenderThumbnail(path)
                                ? Image.file(
                                    File(path),
                                    key: ValueKey(path),
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.broken_image_outlined),
                                  )
                                : _FilePlaceholder(
                                    key: ValueKey(path),
                                    path: path,
                                  ),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: cleaning ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: scheme.scrim.withValues(alpha: 0.28),
                          child: Center(
                            child: SizedBox(
                              width: 74,
                              height: 74,
                              child: CircularProgressIndicator(
                                strokeWidth: 5,
                                color: scheme.primary,
                                backgroundColor:
                                    scheme.surface.withValues(alpha: 0.78),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Preview for formats Flutter cannot decode (HEIC, TIFF, PDF, MKV…).
class _FilePlaceholder extends StatelessWidget {
  const _FilePlaceholder({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = isCleanableDocument(path)
        ? Icons.picture_as_pdf_outlined
        : kindForFile(path) == EntryKind.video
            ? Icons.movie_outlined
            : Icons.image_outlined;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: scheme.primary),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              p.basename(path),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
