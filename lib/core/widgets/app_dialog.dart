import 'package:flutter/material.dart';

import 'app_inputs.dart';

/// The one dialog shell used across the app: consistent title row (with
/// optional trailing actions such as an "edit" icon), scrollable content and
/// bottom actions. Width on phones comes from the app-wide dialog theme.
///
/// Prefer the helpers below for the common cases:
/// - [showConfirmDialog] — yes / no questions,
/// - [showTextPromptDialog] — ask for a single line of text,
/// - [showAppDialog] + [AppDialog] — anything custom (forms, details…).
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    this.titleLeading,
    this.titleActions = const [],
    this.content,
    this.actions = const [],
  });

  final String? title;

  /// Optional widget before the title (e.g. a brand icon).
  final Widget? titleLeading;

  /// Icon buttons shown at the end of the title row (e.g. edit).
  final List<Widget> titleActions;

  final Widget? content;

  /// Bottom buttons, in display order (cancel first, primary last).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final hasHeader =
        title != null || titleLeading != null || titleActions.isNotEmpty;
    return AlertDialog(
      scrollable: true,
      titlePadding: hasHeader
          ? EdgeInsets.fromLTRB(24, 16, titleActions.isEmpty ? 24 : 8, 0)
          : null,
      title: hasHeader
          ? Row(
              children: [
                if (titleLeading != null) ...[
                  titleLeading!,
                  const SizedBox(width: 10),
                ],
                if (title != null) Expanded(child: Text(title!)),
                ...titleActions,
              ],
            )
          : null,
      content: content,
      actions: actions,
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actionsOverflowButtonSpacing: 4,
    );
  }
}

Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) =>
    showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );

/// Yes / no question. Resolves to `true` only when confirmed; dismissing the
/// dialog or pressing cancel gives `false`.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
  Key? confirmKey,
}) async {
  final result = await showAppDialog<bool>(
    context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AppDialog(
        title: title,
        content: message == null ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            key: confirmKey,
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}

/// Asks for one line of text. Resolves to the raw text (not trimmed), or null
/// when cancelled.
Future<String?> showTextPromptDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  required String cancelLabel,
  String? initialValue,
  String? hintText,
}) {
  final controller = TextEditingController(text: initialValue);
  return showAppDialog<String>(
    context,
    builder: (ctx) => AppDialog(
      title: title,
      content: AppTextField(
        controller: controller,
        autofocus: true,
        label: label,
        hint: hintText,
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
