import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/one_page_scroll.dart';
import '../../../core/l10n/app_strings.dart';
import '../../cleaner/presentation/cleaner_page.dart';
import '../../cleaner/presentation/deganeo_icon.dart';
import 'assistant_chat.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({
    this.section = AssistantSection.assistant,
    super.key,
  });

  final AssistantSection section;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

enum AssistantSection { assistant, deganeo }

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  late final PageController _pages =
      PageController(initialPage: widget.section.index);

  @override
  void didUpdateWidget(covariant AssistantScreen old) {
    super.didUpdateWidget(old);
    // Route changed from outside (bottom bar, deep link): slide to the page.
    if (old.section != widget.section &&
        _pages.hasClients &&
        (_pages.page ?? 0).round() != widget.section.index) {
      _pages.animateToPage(
        widget.section.index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  /// Keeps the URL (and so the bottom bar / back handling) in step with the
  /// page the finger settled on.
  void _onPageChanged(int index) {
    final section = AssistantSection.values[index];
    if (section == widget.section) return;
    context
        .go(section == AssistantSection.assistant ? '/assistant' : '/deganeo');
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: isMobile
            ? AnimatedBuilder(
                animation: _pages,
                builder: (context, _) => Text(
                  _pageValue(_pages, widget.section.index) < 0.5
                      ? strings.assistant
                      : 'Deganeo',
                ),
              )
            : _AssistantHeaderTabs(
                controller: _pages,
                initialPage: widget.section.index,
                onSelect: _goTo,
              ),
        bottom: isMobile
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _AssistantHeaderTabs(
                    controller: _pages,
                    initialPage: widget.section.index,
                    onSelect: _goTo,
                    expand: true,
                  ),
                ),
              )
            : null,
      ),
      // Real pager: the page follows the finger, and the header pill follows
      // the same scroll position. Mouse drag is enabled for desktop.
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        child: OnePageScroll(
          builder: (context, physics) => PageView(
            controller: _pages,
            pageSnapping: false,
            physics: physics,
            onPageChanged: _onPageChanged,
            children: [
              const _KeepAlive(child: AssistantChatPage()),
              const _KeepAlive(child: CleanerPage()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps a pager page alive off-screen so the Deganeo queue and the chat
/// survive a swipe to the other page.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Current (fractional) page, falling back to [fallback] before first layout.
double _pageValue(PageController c, int fallback) {
  if (c.hasClients && c.position.haveDimensions) {
    return (c.page ?? fallback.toDouble()).clamp(0.0, 1.0);
  }
  return fallback.toDouble();
}

/// The two-tab pill. Its highlight is positioned from the pager's scroll
/// offset, so it glides under the finger instead of jumping at the end.
class _AssistantHeaderTabs extends ConsumerWidget {
  const _AssistantHeaderTabs({
    required this.controller,
    required this.initialPage,
    required this.onSelect,
    this.expand = false,
  });

  final PageController controller;
  final int initialPage;
  final ValueChanged<int> onSelect;

  /// Fill the whole available width (mobile) instead of capping at 360.
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelLarge;

    Widget label(int index, double t, Widget child) {
      // 1 when this tab is fully selected, 0 when fully away.
      final amount = (index == 0 ? 1 - t : t).clamp(0.0, 1.0);
      final color =
          Color.lerp(scheme.onSurfaceVariant, scheme.primary, amount)!;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onSelect(index),
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(color: color),
              child: DefaultTextStyle.merge(
                style: textStyle?.copyWith(
                  color: color,
                  fontWeight:
                      FontWeight.lerp(FontWeight.w500, FontWeight.w700, amount),
                ),
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 44,
      width: expand ? double.infinity : null,
      constraints: expand ? null : const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(4),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = _pageValue(controller, initialPage);
          return Stack(
            children: [
              Align(
                alignment: Alignment(-1 + 2 * t, 0),
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.10),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  label(
                    0,
                    t,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assistant_outlined, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            strings.assistant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  label(
                    1,
                    t,
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DeganeoIcon(size: 22),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Deganeo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
