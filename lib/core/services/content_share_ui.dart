import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'content_share_service.dart';

/// App-wide instance so the in-flight guard covers every share entry point.
final ContentShareService contentShareService = ContentShareService();

enum _MixedChoice { images, videos }

/// Runs a share and reports the result to the user. Never throws; completes
/// once the share sheet is closed, so callers can re-enable their button.
Future<void> shareWithFeedback(
  BuildContext context,
  AppStrings strings, {
  required String? text,
  required List<String> mediaPaths,
  ContentShareService? service,
}) async {
  final svc = service ?? contentShareService;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final box = context.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;

  void toast(String message) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  var result = await svc.shareContent(
    text: text,
    localMediaPaths: mediaPaths,
    title: strings.share,
    origin: origin,
  );

  if (result.outcome == ShareOutcome.mixedMediaNeedsChoice) {
    if (!context.mounted) return;
    final choice = await _askMixedChoice(context, strings);
    if (choice == null) {
      toast(strings.shareCancelled);
      return;
    }
    toast(strings.shareMixedSeparately);
    final chosen =
        choice == _MixedChoice.images ? result.images : result.videos;
    final skipped = result.skipped;
    result = await svc.shareContent(
      text: text,
      localMediaPaths: chosen,
      title: strings.share,
      origin: origin,
    );
    result = ShareResult(result.outcome, skipped: result.skipped + skipped);
  }

  switch (result.outcome) {
    case ShareOutcome.success:
      if (result.skipped > 0) toast(strings.shareSomeMediaSkipped);
    case ShareOutcome.dismissed:
      toast(strings.shareCancelled);
    case ShareOutcome.noContent:
      toast(strings.shareNothingToShare);
    case ShareOutcome.noValidFiles:
      toast(strings.shareNoValidFiles);
    case ShareOutcome.failure:
      toast(strings.shareFailed);
    case ShareOutcome.busy:
    case ShareOutcome.mixedMediaNeedsChoice:
      break;
  }
}

Future<_MixedChoice?> _askMixedChoice(
  BuildContext context,
  AppStrings strings,
) {
  return showModalBottomSheet<_MixedChoice>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.shareMixedExplanation),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.image_outlined),
              label: Text(strings.shareOnlyImages),
              onPressed: () => Navigator.pop(ctx, _MixedChoice.images),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.videocam_outlined),
              label: Text(strings.shareOnlyVideos),
              onPressed: () => Navigator.pop(ctx, _MixedChoice.videos),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(strings.cancel),
            ),
          ],
        ),
      ),
    ),
  );
}
