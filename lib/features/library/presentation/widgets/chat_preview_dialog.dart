import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../core/l10n/app_strings.dart';

/// A messenger-style preview: shows the note as an outgoing chat message so the
/// user sees how the formatted note reads once shared. Read-only.
class ChatPreviewDialog extends ConsumerWidget {
  const ChatPreviewDialog({
    required this.markdown,
    this.imagePaths = const [],
    super.key,
  });

  final String markdown;
  final List<String> imagePaths;

  static Future<void> show(
    BuildContext context, {
    required String markdown,
    List<String> imagePaths = const [],
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          ChatPreviewDialog(markdown: markdown, imagePaths: imagePaths),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final hasText = markdown.trim().isNotEmpty;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              color: scheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined,
                      size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(strings.preview,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: strings.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Chat area
            Flexible(
              child: Container(
                width: double.infinity,
                color: scheme.surfaceContainerLow,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final path in imagePaths)
                      _OutgoingImageBubble(path: path, scheme: scheme),
                    if (hasText)
                      _OutgoingTextBubble(markdown: markdown, scheme: scheme),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 6, top: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(strings.sent,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                          const SizedBox(width: 4),
                          Icon(Icons.done_all, size: 14, color: scheme.primary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingTextBubble extends StatelessWidget {
  const _OutgoingTextBubble({required this.markdown, required this.scheme});

  final String markdown;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: SelectableText(
            markdown,
            style: TextStyle(
              color: scheme.onPrimary,
              fontFamily: AppConstants.noteFontFamily,
              fontFamilyFallback: AppConstants.noteFontFallback,
              fontSize: 16,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

class _OutgoingImageBubble extends StatelessWidget {
  const _OutgoingImageBubble({required this.path, required this.scheme});

  final String path;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: 500,
            errorBuilder: (_, __, ___) => Container(
              width: 120,
              height: 120,
              color: scheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    );
  }
}
