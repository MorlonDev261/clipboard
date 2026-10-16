import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/widgets/app_dialog.dart';
import '../../../core/l10n/app_strings.dart';
import '../../library/application/library_providers.dart';
import '../application/metadata_cleaner_service.dart';
import '../domain/clean_report.dart';
import 'clean_report_card.dart';
import 'deganeo_icon.dart';

/// How a [showDeganeoCleanFlow] run ended.
typedef DeganeoOutcome = ({int replaced, int copied});

/// Cleans [paths] with Deganeo **one image at a time**: each file is cleaned
/// and verified, its report is shown, and the user picks "replace the original"
/// or "keep a copy" (or skips it) before the next one starts. A single image
/// goes through the same flow with a "1 of 1" header.
///
/// Returns what was saved, or `null` if nothing was.
Future<DeganeoOutcome?> showDeganeoCleanFlow(
  BuildContext context, {
  required List<String> paths,
  required String parentDir,
}) {
  return showDialog<DeganeoOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeganeoCleanDialog(paths: paths, parentDir: parentDir),
  );
}

class _DeganeoCleanDialog extends ConsumerStatefulWidget {
  const _DeganeoCleanDialog({required this.paths, required this.parentDir});

  final List<String> paths;
  final String parentDir;

  @override
  ConsumerState<_DeganeoCleanDialog> createState() =>
      _DeganeoCleanDialogState();
}

class _DeganeoCleanDialogState extends ConsumerState<_DeganeoCleanDialog> {
  final _cleaner = const MetadataCleanerService();
  int _index = 0;
  int _replaced = 0;
  int _copied = 0;
  bool _working = true;
  bool _saving = false;
  bool _detailsOpen = false;
  CleanReport? _report;
  bool _closed = false;

  String get _current => widget.paths[_index];

  @override
  void initState() {
    super.initState();
    unawaited(_cleanCurrent());
  }

  @override
  void dispose() {
    _closed = true;
    _deleteTemp(_report?.outputPath);
    super.dispose();
  }

  Future<void> _cleanCurrent() async {
    final path = _current;
    setState(() {
      _working = true;
      _report = null;
      _detailsOpen = false;
    });
    CleanReport report;
    try {
      report = await _cleaner.clean(path);
    } catch (_) {
      report = CleanReport(
        status: CleanStatus.failed,
        format: MediaFormat.unknown,
        sourcePath: path,
      );
    }
    if (_closed) {
      _deleteTemp(report.outputPath);
      return;
    }
    setState(() {
      _report = report;
      _working = false;
      _detailsOpen = !report.isClean;
    });
  }

  Future<void> _save({required bool replace}) async {
    final out = _report?.outputPath;
    if (out == null || _saving) return;
    final strings = ref.read(appStringsProvider);
    setState(() => _saving = true);
    try {
      await ref.read(libraryControllerProvider).storeCleaned(
            _current,
            out,
            replace: replace,
            parentDir: widget.parentDir,
          );
      if (replace) {
        _replaced++;
      } else {
        _copied++;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(strings.genericError)));
      }
    }
    _deleteTemp(out);
    _report = null;
    _saving = false;
    _next();
  }

  void _next() {
    if (!mounted) return;
    if (_index + 1 >= widget.paths.length) {
      Navigator.of(context).pop<DeganeoOutcome>(
        _replaced + _copied == 0
            ? null
            : (replaced: _replaced, copied: _copied),
      );
      return;
    }
    _index++;
    unawaited(_cleanCurrent());
  }

  void _skip() {
    _deleteTemp(_report?.outputPath);
    _report = null;
    _next();
  }

  void _deleteTemp(String? path) {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Best effort: a stray temp copy is purged on the next Deganeo start.
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final report = _report;
    final canSave = report != null && report.hasOutput && !_saving;

    return AppDialog(
      titleLeading: const DeganeoIcon(size: 28),
      title: widget.paths.length > 1
          ? strings.deganeoProgress(_index + 1, widget.paths.length)
          : 'Deganeo',
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                p.basename(_current),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 150,
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Image.file(
                      File(_current),
                      fit: BoxFit.contain,
                      cacheHeight: 300,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_outlined, size: 48),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_working || _saving)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (report != null)
                CleanReportCard(
                  report: report,
                  expanded: _detailsOpen,
                  onToggle: () => setState(() => _detailsOpen = !_detailsOpen),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _working || _saving ? null : _skip,
          child: Text(
            _index + 1 >= widget.paths.length &&
                    (report == null || !report.hasOutput)
                ? strings.cancel
                : strings.deganeoSkip,
          ),
        ),
        OutlinedButton(
          onPressed: canSave ? () => _save(replace: false) : null,
          child: Text(strings.deganeoKeepCopy),
        ),
        FilledButton(
          onPressed: canSave ? () => _save(replace: true) : null,
          child: Text(strings.deganeoReplaceOriginal),
        ),
      ],
    );
  }
}
