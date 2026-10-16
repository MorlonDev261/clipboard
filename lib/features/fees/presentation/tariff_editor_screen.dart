import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/one_page_scroll.dart';
import '../../../core/widgets/app_inputs.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/l10n/app_strings.dart';
import '../../accounting/presentation/accounting_screen.dart' show formatAr;
import '../application/tariff_providers.dart';
import '../data/madagascar_tariffs.dart';
import '../domain/mobile_money_fees.dart';

/// Edits one operator: name, "verified" flag and its four fee grids.
class TariffEditorScreen extends ConsumerStatefulWidget {
  const TariffEditorScreen({
    super.key,
    required this.tariff,
    this.isNew = false,
  });

  final OperatorTariff tariff;
  final bool isNew;

  @override
  ConsumerState<TariffEditorScreen> createState() => _TariffEditorState();
}

class _TariffEditorState extends ConsumerState<TariffEditorScreen> {
  late final TextEditingController _name;
  late bool _official;
  late List<FeeBracket> _withdraw;
  late List<FeeBracket> _same;
  late List<FeeBracket> _other;
  late List<FeeBracket> _app;

  @override
  void initState() {
    super.initState();
    final t = widget.tariff;
    _name = TextEditingController(text: t.name);
    _official = t.official;
    _withdraw = [...t.withdraw];
    _same = [...t.transfer];
    _other = [...?t.transferOther];
    _app = [...?t.transferApp];
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<FeeBracket> _sorted(List<FeeBracket> l) =>
      [...l]..sort((a, b) => a.min.compareTo(b.min));

  Future<void> _save() async {
    final s = ref.read(appStringsProvider);
    final name = _name.text.trim();
    String? error;
    if (name.isEmpty) {
      error = s.feeOperatorName;
    } else if (name != widget.tariff.name &&
        ref.read(currentTariffsProvider).any((t) => t.name == name)) {
      error = s.feeNameTaken;
    } else if (_withdraw.isEmpty || _same.isEmpty) {
      error = s.feeNeedGrids;
    }
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await ref.read(tariffsProvider.notifier).upsert(
          OperatorTariff(
            name: name,
            official: _official,
            withdraw: _sorted(_withdraw),
            transfer: _sorted(_same),
            transferOther: _other.isEmpty ? null : _sorted(_other),
            transferApp: _app.isEmpty ? null : _sorted(_app),
          ),
          replacing: widget.isNew ? null : widget.tariff.name,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final s = ref.read(appStringsProvider);
    final ok = await showConfirmDialog(
      context,
      title: s.feeDeleteOperator,
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(tariffsProvider.notifier).remove(widget.tariff.name);
    if (mounted) Navigator.pop(context);
  }

  /// The grid shipped with the app for this operator, if it is a built-in one.
  OperatorTariff? get _builtIn {
    if (widget.isNew) return null;
    for (final t in madagascarTariffs) {
      if (t.name == widget.tariff.name) return t;
    }
    return null;
  }

  Future<void> _restoreOfficial() async {
    final builtIn = _builtIn;
    if (builtIn == null) return;
    final s = ref.read(appStringsProvider);
    final ok = await showConfirmDialog(
      context,
      title: s.feeRestoreOfficial,
      message: s.feeRestoreOfficialConfirm,
      confirmLabel: s.feeRestoreOfficial,
      cancelLabel: s.cancel,
    );
    if (!ok) return;
    await ref
        .read(tariffsProvider.notifier)
        .upsert(builtIn, replacing: widget.tariff.name);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew ? s.feeAddOperator : widget.tariff.name),
          actions: [
            if (!widget.isNew)
              IconButton(
                tooltip: s.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            TextButton(onPressed: _save, child: Text(s.save)),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: s.feeTabWithdraw),
              Tab(text: s.feeTabSame),
              Tab(text: s.feeTabOther),
              Tab(text: s.feeTabApp),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  AppTextField(
                    controller: _name,
                    label: s.feeOperatorName,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.feeVerifiedSwitch),
                    value: _official,
                    onChanged: (v) => setState(() => _official = v),
                  ),
                  if (_builtIn != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _restoreOfficial,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: Text(s.feeRestoreOfficial),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AppTabBarView(
                children: [
                  _GridEditor(
                    title: s.feeGridWithdraw,
                    brackets: _withdraw,
                    strings: s,
                    onChanged: (l) => setState(() => _withdraw = l),
                  ),
                  _GridEditor(
                    title: s.feeGridSame,
                    brackets: _same,
                    strings: s,
                    onChanged: (l) => setState(() => _same = l),
                  ),
                  _GridEditor(
                    title: s.feeGridOther,
                    brackets: _other,
                    strings: s,
                    optional: true,
                    onChanged: (l) => setState(() => _other = l),
                  ),
                  _GridEditor(
                    title: s.feeGridApp,
                    brackets: _app,
                    strings: s,
                    optional: true,
                    onChanged: (l) => setState(() => _app = l),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridEditor extends StatelessWidget {
  const _GridEditor({
    required this.title,
    required this.brackets,
    required this.strings,
    required this.onChanged,
    this.optional = false,
  });

  final String title;
  final List<FeeBracket> brackets;
  final AppStrings strings;
  final ValueChanged<List<FeeBracket>> onChanged;
  final bool optional;

  bool get _overlaps {
    final l = [...brackets]..sort((a, b) => a.min.compareTo(b.min));
    for (var i = 1; i < l.length; i++) {
      if (l[i].min <= l[i - 1].max) return true;
    }
    return false;
  }

  Future<void> _edit(BuildContext context, {int? index}) async {
    final existing = index == null ? null : brackets[index];
    final sorted = [...brackets]..sort((a, b) => a.min.compareTo(b.min));
    final suggestedMin = sorted.isEmpty ? 100 : sorted.last.max + 1;
    final result = await showAppDialog<_BracketResult>(
      context,
      builder: (_) => _BracketDialog(
        strings: strings,
        initial: existing ?? FeeBracket(suggestedMin, suggestedMin + 4999, 0),
        canDelete: existing != null,
      ),
    );
    if (result == null) return;
    final next = [...brackets];
    if (result.delete) {
      next.removeAt(index!);
    } else if (index == null) {
      next.add(result.bracket!);
    } else {
      next[index] = result.bracket!;
    }
    next.sort((a, b) => a.min.compareTo(b.min));
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...brackets]..sort((a, b) => a.min.compareTo(b.min));
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(title, style: theme.textTheme.titleSmall),
        ),
        if (optional)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child:
                Text(strings.feeGridOptional, style: theme.textTheme.bodySmall),
          ),
        if (_overlaps)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(strings.feeBracketOverlap,
                style: TextStyle(color: theme.colorScheme.error)),
          ),
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(strings.feeGridEmpty)),
          ),
        for (final b in sorted)
          ListTile(
            title: Text('${formatAr(b.min)} : ${formatAr(b.max)}'),
            trailing: Text(formatAr(b.fee),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            onTap: () => _edit(context, index: brackets.indexOf(b)),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add),
            label: Text(strings.feeAddBracket),
          ),
        ),
      ],
    );
  }
}

class _BracketResult {
  const _BracketResult.save(FeeBracket this.bracket) : delete = false;
  const _BracketResult.remove()
      : bracket = null,
        delete = true;

  final FeeBracket? bracket;
  final bool delete;
}

class _BracketDialog extends StatefulWidget {
  const _BracketDialog({
    required this.strings,
    required this.initial,
    required this.canDelete,
  });

  final AppStrings strings;
  final FeeBracket initial;
  final bool canDelete;

  @override
  State<_BracketDialog> createState() => _BracketDialogState();
}

class _BracketDialogState extends State<_BracketDialog> {
  late final _min = TextEditingController(text: '${widget.initial.min}');
  late final _max = TextEditingController(text: '${widget.initial.max}');
  late final _fee = TextEditingController(text: '${widget.initial.fee}');
  bool _invalid = false;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _fee.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppAmountField(
          controller: c,
          label: label,
          hint: hint,
          onChanged: (_) {
            if (_invalid) setState(() => _invalid = false);
          },
        ),
      );

  void _submit() {
    final min = AppAmountField.parse(_min.text);
    final max = AppAmountField.parse(_max.text);
    final fee = AppAmountField.parse(_fee.text);
    if (min == null || max == null || fee == null || max < min) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, _BracketResult.save(FeeBracket(min, max, fee)));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return AppDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field(_min, s.feeBracketFrom, s.example('5 001')),
          _field(_max, s.feeBracketTo, s.example('10 000')),
          _field(_fee, s.feeBracketFee, s.example('350')),
          if (_invalid)
            Text(s.feeBracketInvalid,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
      actions: [
        if (widget.canDelete)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const _BracketResult.remove()),
            child: Text(s.delete),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _submit, child: Text(s.save)),
      ],
    );
  }
}
