import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/list_format.dart';
import '../../../../core/formatting/unicode_styler.dart';
import '../../../../core/l10n/app_strings.dart';

enum FormatAttr { bold, italic, underline, strike, code }

/// A compact, horizontally-scrollable toolbar that applies *native* Unicode
/// styling — no markup.
///
/// Two modes, like a normal editor:
///  * With a selection, a button toggles the style on the selected characters.
///  * With no selection, a button toggles the *active style*: what you type next
///    comes out styled (the transformation on type happens in the note screen).
/// A button is highlighted when its style is active for the selection / for the
/// pending active style.
class FormattingToolbar extends ConsumerWidget {
  const FormattingToolbar({
    required this.controller,
    required this.activeStyle,
    required this.onActiveStyleChanged,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final InlineStyle activeStyle;
  final ValueChanged<InlineStyle> onActiveStyleChanged;
  final FocusNode? focusNode;

  static const _styler = UnicodeStyler();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    // Style shown as "active": the selection's detected style, or the pending
    // active style when there is no selection.
    final (:start, :end) = _range();
    final shown = start == end
        ? activeStyle
        : _styler.detectStyle(controller.text.substring(start, end));

    final buttons = <Widget>[
      _btn(context, Icons.format_bold, strings.bold, shown.bold,
          () => _onInline(context, strings, FormatAttr.bold)),
      _btn(context, Icons.format_italic, strings.italic, shown.italic,
          () => _onInline(context, strings, FormatAttr.italic)),
      _btn(context, Icons.format_strikethrough, strings.strikethrough,
          shown.strike, () => _onInline(context, strings, FormatAttr.strike)),
      const _Divider(),
      _btn(context, Icons.format_list_bulleted, strings.bulletList, false,
          _toggleBullet),
      _btn(context, Icons.format_list_numbered, strings.numberedList, false,
          _toggleNumbered),
      const _Divider(),
      _btn(context, Icons.format_clear, strings.clearFormatting, false,
          _clearFormatting),
    ];

    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: buttons),
      ),
    );
  }

  Widget _btn(BuildContext context, IconData icon, String tooltip, bool active,
          VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: IconButton(
          icon: Icon(icon, size: 20),
          tooltip: tooltip,
          isSelected: active,
          visualDensity: VisualDensity.compact,
          style: active
              ? IconButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                )
              : null,
          onPressed: onTap,
        ),
      );

  // --- Inline styles ---------------------------------------------------------

  void _onInline(BuildContext context, AppStrings strings, FormatAttr attr) {
    final (:start, :end) = _range();
    if (start == end) {
      // No selection → toggle the pending active style.
      onActiveStyleChanged(_toggle(activeStyle, attr));
      return;
    }
    final selected = controller.text.substring(start, end);
    final target = _toggle(_styler.detectStyle(selected), attr);
    _replaceSelection(_styler.restyle(selected, target), start, end);
  }

  InlineStyle _toggle(InlineStyle s, FormatAttr attr) => switch (attr) {
        FormatAttr.bold => s.copyWith(bold: !s.bold),
        FormatAttr.italic => s.copyWith(italic: !s.italic),
        FormatAttr.underline => s.copyWith(underline: !s.underline),
        FormatAttr.strike => s.copyWith(strike: !s.strike),
        FormatAttr.code => s.copyWith(code: !s.code),
      };

  void _clearFormatting() {
    final (:start, :end) = _range();
    if (start == end) {
      onActiveStyleChanged(InlineStyle.none); // turn off pending styles
      return;
    }
    final selected = controller.text.substring(start, end);
    final cleared = _styler
        .plainify(selected)
        .split('\n')
        .map((l) => l.replaceFirst(ListFormat.anyRe, ''))
        .join('\n');
    _replaceSelection(cleared, start, end);
  }

  // --- Lists (plain, native prefixes) ---------------------------------------

  void _toggleBullet() => _toggleList(numbered: false);
  void _toggleNumbered() => _toggleList(numbered: true);

  void _toggleList({required bool numbered}) {
    final text = controller.text;
    final (:start, :end) = _range();
    final lineStart = text.lastIndexOf('\n', start > 0 ? start - 1 : 0) + 1;
    var lineEnd = text.indexOf('\n', end);
    if (lineEnd == -1) lineEnd = text.length;

    final lines = text.substring(lineStart, lineEnd).split('\n');
    final match = numbered ? ListFormat.numberedRe : ListFormat.bulletRe;
    final nonEmpty = lines.where((l) => l.trim().isNotEmpty).toList();

    // Nothing to (un)mark — the caret sits on an empty line (e.g. a fresh note):
    // start the list by inserting a single marker, caret ready after it.
    if (nonEmpty.isEmpty) {
      final prefix = numbered ? ListFormat.numbered(1) : ListFormat.bullet;
      final newText = text.replaceRange(lineStart, lineEnd, prefix);
      _apply(newText, TextSelection.collapsed(offset: lineStart + prefix.length));
      return;
    }

    final allMarked = nonEmpty.every(match.hasMatch);

    final result = <String>[];
    var counter = 0;
    for (final line in lines) {
      if (line.trim().isEmpty) {
        result.add(line);
        continue;
      }
      if (allMarked) {
        result.add(line.replaceFirst(ListFormat.anyRe, ''));
      } else {
        final bare = line.replaceFirst(ListFormat.anyRe, '');
        counter++;
        result.add((numbered ? ListFormat.numbered(counter) : ListFormat.bullet) +
            bare);
      }
    }
    final newBlock = result.join('\n');
    final newText = text.replaceRange(lineStart, lineEnd, newBlock);
    // Place a collapsed caret at the end of the (re)formatted block instead of
    // selecting its text: nothing is highlighted, and pressing Enter continues
    // the list (see NoteScreen._handleListNewline) rather than replacing the
    // selection.
    _apply(
      newText,
      TextSelection.collapsed(offset: lineStart + newBlock.length),
    );
  }

  // --- Low-level controller helpers -----------------------------------------

  void _apply(String text, TextSelection selection) {
    controller.value = TextEditingValue(
      text: text,
      selection: selection,
      composing: TextRange.empty,
    );
    focusNode?.requestFocus();
  }

  ({int start, int end}) _range() {
    final sel = controller.selection;
    final len = controller.text.length;
    final start = sel.start < 0 ? len : sel.start;
    final end = sel.end < 0 ? len : sel.end;
    return (start: start, end: end);
  }

  void _replaceSelection(String replacement, int start, int end) {
    final newText = controller.text.replaceRange(start, end, replacement);
    _apply(
      newText,
      TextSelection(baseOffset: start, extentOffset: start + replacement.length),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          height: 24,
          child: VerticalDivider(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
        ),
      );
}
