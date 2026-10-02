import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/empty_state.dart';
import '../../cleaner/presentation/cleaner_page.dart';

class _Message {
  const _Message(this.text, {required this.fromUser});

  final String text;
  final bool fromUser;
}

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
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Message>[];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(AppStrings strings) {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Message(text, fromUser: true));
      _messages.add(_Message(strings.assistantComingSoon, fromUser: false));
      _input.clear();
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final isDeganeo = widget.section == AssistantSection.deganeo;

    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: isMobile
            ? Text(isDeganeo ? 'Deganeo' : strings.assistant)
            : _AssistantHeaderTabs(selected: widget.section),
        bottom: isMobile
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _AssistantHeaderTabs(
                    selected: widget.section,
                    expand: true,
                  ),
                ),
              )
            : null,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -300 && !isDeganeo) {
            context.go('/deganeo');
          } else if (v > 300 && isDeganeo) {
            context.go('/assistant');
          }
        },
        child: _buildBody(isDeganeo, strings),
      ),
    );
  }

  Widget _buildBody(bool isDeganeo, AppStrings strings) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: isDeganeo ? const CleanerPage() : _buildAssistant(strings),
    );
  }

  Widget _buildAssistant(AppStrings strings) {
    return Column(
      key: const ValueKey('assistant-page'),
      children: [
        Expanded(
          child: _messages.isEmpty
              ? EmptyState(
                  icon: Icons.assistant_outlined,
                  title: strings.assistant,
                  message: strings.assistantIntro,
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) => _Bubble(message: _messages[i]),
                ),
        ),
        _Composer(
          controller: _input,
          hint: strings.assistantHint,
          onSend: () => _send(strings),
        ),
      ],
    );
  }
}

class _AssistantHeaderTabs extends ConsumerWidget {
  const _AssistantHeaderTabs({required this.selected, this.expand = false});

  final AssistantSection selected;

  /// Fill the whole available width (mobile) instead of capping at 360.
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return Container(
      height: 44,
      width: expand ? double.infinity : null,
      constraints: expand ? null : const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _AssistantHeaderTab(
              selected: selected == AssistantSection.assistant,
              onTap: () {
                if (selected != AssistantSection.assistant) {
                  context.go('/assistant');
                }
              },
              child: Row(
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
          ),
          Expanded(
            child: _AssistantHeaderTab(
              selected: selected == AssistantSection.deganeo,
              onTap: () {
                if (selected != AssistantSection.deganeo) {
                  context.go('/deganeo');
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: SvgPicture.asset(
                        'assets/deganeo/logo-Deganeo.svg',
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Flexible(
                    child: Text(
                      'Deganeo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantHeaderTab extends StatelessWidget {
  const _AssistantHeaderTab({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: IconTheme.merge(
            data: IconThemeData(
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            child: DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fromUser = message.fromUser;
    final bg = fromUser ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = fromUser ? scheme.onPrimary : scheme.onSurface;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromUser ? 16 : 4),
            bottomRight: Radius.circular(fromUser ? 4 : 16),
          ),
        ),
        child: Text(message.text, style: TextStyle(color: fg)),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hint,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: hint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onSend,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
