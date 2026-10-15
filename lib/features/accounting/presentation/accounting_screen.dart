import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/widgets/app_inputs.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/edit_mode_provider.dart';
import '../../../core/providers/workspace_providers.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/accounting_providers.dart';
import '../domain/ledger_entry.dart';

String formatAr(int value) {
  final digits = value.abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '\u00A0',
  );
  return '${value < 0 ? '-' : ''}$grouped\u00A0Ar';
}

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

extension on LedgerType {
  String text(AppStrings s) => switch (this) {
        LedgerType.purchase => s.purchase,
        LedgerType.sale => s.sale,
        LedgerType.expense => s.expense,
      };
}

extension on LedgerAccount {
  String text(AppStrings s) => this == LedgerAccount.cash ? s.cash : label;
}

class AccountingScreen extends ConsumerStatefulWidget {
  const AccountingScreen({super.key});

  @override
  ConsumerState<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends ConsumerState<AccountingScreen> {
  LedgerAccount? _filter;

  Future<void> _openEditor([LedgerEntry? entry]) async {
    final strings = ref.read(appStringsProvider);
    final editing = ref.read(editModeProvider);
    final result = await showAppDialog<_EditorResult>(
      context,
      builder: (_) => _EntryDialog(
        entry: entry,
        strings: strings,
        startEditing: entry == null || editing,
      ),
    );
    if (result == null) return;
    final controller = ref.read(ledgerProvider.notifier);
    if (result.delete) {
      await controller.remove(entry!.id);
    } else {
      await controller.save(result.entry!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final hasWorkspace = ref.watch(workspaceRootProvider) != null;
    final editing = ref.watch(editModeProvider);
    final entries = ref.watch(ledgerProvider).value ?? const <LedgerEntry>[];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final balance = entries.fold<int>(0, (s, e) => s + e.signedAmount);
    int balanceOf(LedgerAccount a) => entries
        .where((e) => e.account == a)
        .fold<int>(0, (s, e) => s + e.signedAmount);
    final shown = _filter == null
        ? entries
        : entries.where((e) => e.account == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/menu')),
        title: Text(strings.accounting),
        actions: [
          IconButton(
            key: const ValueKey('ledger-fees'),
            tooltip: 'Deganeo',
            icon: const Icon(Icons.currency_exchange_rounded),
            onPressed: () => context.push('/fees'),
          ),
          if (hasWorkspace) const EditModeButton(),
        ],
      ),
      floatingActionButton: hasWorkspace && editing
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: Text(strings.newTransaction),
            )
          : null,
      body: !hasWorkspace
          ? EmptyState(
              icon: Icons.folder_off_outlined,
              title: strings.needWorkspace,
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.availableBalance,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatAr(balance),
                        key: const ValueKey('ledger-balance'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: balance < 0
                              ? scheme.error
                              : scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          for (final a in LedgerAccount.values)
                            Text(
                              '${a.text(strings)}: ${formatAr(balanceOf(a))}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.onPrimaryContainer),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(strings.all),
                          selected: _filter == null,
                          onSelected: (_) => setState(() => _filter = null),
                        ),
                      ),
                      for (final a in LedgerAccount.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(a.text(strings)),
                            selected: _filter == a,
                            onSelected: (_) => setState(() => _filter = a),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: shown.isEmpty
                      ? EmptyState(
                          icon: Icons.account_balance_wallet_outlined,
                          title: strings.noTransactions,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: shown.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = shown[i];
                            final credit =
                                e.direction == LedgerDirection.credit;
                            final color =
                                credit ? Colors.green.shade700 : scheme.error;
                            return ListTile(
                              onTap: () => _openEditor(e),
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.12),
                                child: Icon(
                                  credit
                                      ? Icons.south_west_rounded
                                      : Icons.north_east_rounded,
                                  color: color,
                                ),
                              ),
                              title: Text(
                                e.note.isEmpty ? e.type.text(strings) : e.note,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${formatDate(e.date)} · ${e.type.text(strings)}'
                                ' · ${e.account.text(strings)}',
                              ),
                              trailing: Text(
                                '${credit ? '+' : '-'}${formatAr(e.amount)}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _EditorResult {
  const _EditorResult.save(LedgerEntry this.entry) : delete = false;
  const _EditorResult.remove()
      : entry = null,
        delete = true;

  final LedgerEntry? entry;
  final bool delete;
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({
    required this.entry,
    required this.strings,
    required this.startEditing,
  });

  final LedgerEntry? entry;
  final AppStrings strings;
  final bool startEditing;

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  late LedgerDirection _direction;
  late LedgerType _type;
  late LedgerAccount _account;
  late DateTime _date;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  bool _amountInvalid = false;
  late bool _editing;

  @override
  void initState() {
    super.initState();
    _editing = widget.startEditing;
    final e = widget.entry;
    _type = e?.type ?? LedgerType.sale;
    _direction = e?.direction ?? _type.defaultDirection;
    _account = e?.account ?? LedgerAccount.cash;
    _date = e?.date ?? DateTime.now();
    _amount = TextEditingController(text: e == null ? '' : '${e.amount}');
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final amount = AppAmountField.parse(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _amountInvalid = true);
      return;
    }
    Navigator.pop(
      context,
      _EditorResult.save(LedgerEntry(
        id: widget.entry?.id ?? const Uuid().v4(),
        date: _date,
        amount: amount,
        account: _account,
        type: _type,
        direction: _direction,
        note: _note.text.trim(),
      )),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );

  Widget _buildReadOnly(AppStrings s) {
    final e = widget.entry!;
    final credit = e.direction == LedgerDirection.credit;
    return AppDialog(
      title: e.type.text(s),
      titleActions: [
        IconButton(
          key: const ValueKey('ledger-dialog-edit'),
          tooltip: s.edit,
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => setState(() => _editing = true),
        ),
      ],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _detailRow(s.amount, '${credit ? '+' : '-'}${formatAr(e.amount)}'),
          _detailRow(s.account, e.account.text(s)),
          _detailRow(s.date, formatDate(e.date)),
          if (e.note.isNotEmpty) _detailRow(s.note, e.note),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.closeAction),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    if (!_editing) return _buildReadOnly(s);
    return AppDialog(
      title: widget.entry == null ? s.newTransaction : s.editTransaction,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<LedgerDirection>(
              segments: [
                ButtonSegment(
                    value: LedgerDirection.credit, label: Text(s.credit)),
                ButtonSegment(
                    value: LedgerDirection.debit, label: Text(s.debit)),
              ],
              selected: {_direction},
              onSelectionChanged: (v) => setState(() => _direction = v.first),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LedgerType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: s.type),
              items: [
                for (final t in LedgerType.values)
                  DropdownMenuItem(value: t, child: Text(t.text(s))),
              ],
              onChanged: (t) {
                if (t == null) return;
                setState(() {
                  _type = t;
                  _direction = t.defaultDirection;
                });
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<LedgerAccount>(
              initialValue: _account,
              decoration: InputDecoration(labelText: s.account),
              items: [
                for (final a in LedgerAccount.values)
                  DropdownMenuItem(value: a, child: Text(a.text(s))),
              ],
              onChanged: (a) => setState(() => _account = a ?? _account),
            ),
            const SizedBox(height: 8),
            AppAmountField(
              controller: _amount,
              label: s.amount,
              hint: s.example('25 000'),
              errorText: _amountInvalid ? s.invalidAmount : null,
              onChanged: (_) {
                if (_amountInvalid) setState(() => _amountInvalid = false);
              },
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: s.date,
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(formatDate(_date)),
              ),
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: _note,
              minLines: 1,
              maxLines: 3,
              label: s.note,
            ),
          ],
        ),
      ),
      actions: [
        if (widget.entry != null)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const _EditorResult.remove()),
            child: Text(s.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(s.save)),
      ],
    );
  }
}
