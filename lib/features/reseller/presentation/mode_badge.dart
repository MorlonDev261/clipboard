import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_providers.dart';
import '../../../shared/enums/enums.dart';
import '../application/reseller_providers.dart';

/// Collapsible badge shown under the "Influencor" title once a reseller session
/// exists. Collapsed: one small pill with the current space. Expanded: both
/// spaces side by side, tap one to switch. The two words are product names and
/// are deliberately never translated.
class ModeBadge extends ConsumerStatefulWidget {
  const ModeBadge({super.key});

  @override
  ConsumerState<ModeBadge> createState() => _ModeBadgeState();
}

class _ModeBadgeState extends ConsumerState<ModeBadge> {
  var _open = false;

  static String _label(AppMode m) =>
      m == AppMode.clipboard ? 'clipboard' : 'reseller';

  Future<void> _select(AppMode mode) async {
    setState(() => _open = false);
    await ref.read(settingsControllerProvider.notifier).setAppMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(modeBadgeVisibleProvider)) return const SizedBox.shrink();
    final mode = ref.watch(appModeProvider);
    final scheme = Theme.of(context).colorScheme;
    const style =
        TextStyle(fontSize: 11, height: 1.1, fontWeight: FontWeight.w600);

    Widget segment(AppMode m) {
      final selected = m == mode;
      return InkWell(
        key: ValueKey('mode-${m.name}'),
        borderRadius: BorderRadius.circular(999),
        onTap: () => _select(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _label(m),
            style: style.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: _open
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    segment(AppMode.clipboard),
                    segment(AppMode.reseller),
                    InkWell(
                      key: const ValueKey('mode-collapse'),
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setState(() => _open = false),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 3),
                        child: Icon(Icons.chevron_left,
                            size: 16, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                )
              : InkWell(
                  key: const ValueKey('mode-expand'),
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() => _open = true),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(9, 4, 5, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_label(mode),
                            style: style.copyWith(color: scheme.primary)),
                        Icon(Icons.chevron_right,
                            size: 14, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
