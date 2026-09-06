import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/business_info_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/read_once.dart';
import '../../providers/shop_provider.dart';
import '../../services/ledger_statement_service.dart';
import 'record_payment_sheet.dart';
import '../../utils/money.dart';
import '../../theme/brand_config.dart';
import '../../widgets/ui/ui.dart';

final _dateFmt = DateFormat('dd MMM yyyy');



String _modeLabel(PaymentMode mode) {
  switch (mode) {
    case PaymentMode.upi:
      return 'UPI';
    case PaymentMode.cash:
      return 'Cash';
    case PaymentMode.bank:
      return 'Bank';
    case PaymentMode.cheque:
      return 'Cheque';
  }
}

String _statusLabel(BillStatus status) => switch (status) {
      BillStatus.paid => 'Paid',
      BillStatus.partial => 'Partial',
      BillStatus.unpaid => 'Unpaid',
    };

MaterialColor _statusColor(BillStatus status) => switch (status) {
      BillStatus.paid => Colors.green,
      BillStatus.partial => Colors.orange,
      BillStatus.unpaid => Colors.red,
    };

typedef LedgerFilters = ({
  DateTimeRange? range,
  BillStatus? status,
  LedgerType? type,
});

class ShopLedgerScreen extends ConsumerStatefulWidget {
  const ShopLedgerScreen({super.key, required this.shopId});

  final int shopId;

  @override
  ConsumerState<ShopLedgerScreen> createState() => _ShopLedgerScreenState();
}

class _ShopLedgerScreenState extends ConsumerState<ShopLedgerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTimeRange? _range;
  BillStatus? _statusFilter;
  LedgerType? _typeFilter;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _activeFilterCount => [_range, _statusFilter, _typeFilter]
      .where((f) => f != null)
      .length;

  String get _filterSummary {
    final parts = <String>[];
    if (_typeFilter != null) {
      parts.add(_typeFilter == LedgerType.bill ? 'Bills' : 'Payments');
    }
    if (_statusFilter != null) parts.add(_statusLabel(_statusFilter!));
    if (_range != null) {
      parts.add(
          '${DateFormat('dd MMM').format(_range!.start)} – ${DateFormat('dd MMM').format(_range!.end)}');
    }
    return parts.isEmpty ? 'All entries' : parts.join(' · ');
  }

  void _openPaymentSheet() {
    unawaited(showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecordPaymentSheet(shopId: widget.shopId),
    ));
  }

  /// Pick a period, then build and share that period's statement.
  ///
  /// The rows come from the same unfiltered ledger stream this screen renders
  /// and are cut to the period by the same rule the History filter uses, so
  /// the PDF and the screen cannot report different figures for one period.
  Future<void> _exportStatement() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _range ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      helpText: 'Statement period',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: kBrandBrown),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() => _exporting = true);
    try {
      final shop = await ref.readFutureOnce(shopByIdProvider(widget.shopId));
      if (shop == null) return;
      final business = await ref.read(businessInfoProvider.future);
      final entries = await ref.readStreamOnce(shopLedgerProvider((
        shopId: widget.shopId,
        range: null,
        status: null,
        type: null,
      )));

      await shareLedgerStatement(
        brand: ref.read(brandProvider),
        shop: shop,
        business: business,
        entries: entries,
        from: picked.start,
        to: picked.end,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not build the statement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<LedgerFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LedgerFilterSheet(
        initial: (range: _range, status: _statusFilter, type: _typeFilter),
      ),
    );
    if (result != null) {
      setState(() {
        _range = result.range;
        _statusFilter = result.status;
        _typeFilter = result.type;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _range = null;
      _statusFilter = null;
      _typeFilter = null;
    });
  }

  // Editing a payment is deliberately not supported — a payment's allocations
  // are derived, so re-pointing them safely means recomputing FIFO anyway.
  // Delete and re-record is the correction path.
  Future<void> _confirmDeletePayment(LedgerEntry entry) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete Payment',
      message: 'Delete the '
          '${ref.read(brandProvider).moneyDecimal(entry.amount)} payment '
          'dated ${_dateFmt.format(entry.date)}?',
      detail: 'Any bills it settled go back to unpaid. To correct a payment, '
          'delete it and record it again.',
    );
    if (confirmed) {
      await ref.read(databaseProvider).ledgerDao.deletePayment(entry.paymentId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(shopByIdProvider(widget.shopId)).value;
    final statsAsync = ref.watch(shopStatsProvider(widget.shopId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(shop?.name ?? 'Statement',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            // `Statement`, not `Ledger`. The drawer's Ledger is the whole
            // business; this is one shop's bills, payments and running
            // balance. Two screens called the same word is how the owner ends
            // up on the wrong one.
            Text(
              shop?.area == null ? 'Statement' : 'Statement · ${shop!.area}',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export Statement',
            onPressed: _exporting ? null : _exportStatement,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Outstanding'),
            Tab(text: 'History'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPaymentSheet,
        backgroundColor: kBrandGold,
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Record Payment'),
      ),
      body: Column(
        children: [
          _StatsHeader(statsAsync: statsAsync),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOutstandingTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Outstanding ─────────────────────────────────────────────────────────
  // Only bills that still owe something, oldest first — "who owes me what, and
  // since when". Deliberately unfiltered: this tab answers one question.

  Widget _buildOutstandingTab() {
    final billsAsync = ref.watch(shopLedgerProvider((
      shopId: widget.shopId,
      range: null,
      status: null,
      type: LedgerType.bill,
    )));

    return billsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (bills) {
        final open =
            bills.where((b) => b.billStatus != BillStatus.paid).toList();

        if (open.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    bills.isEmpty
                        ? Icons.receipt_long_outlined
                        : Icons.check_circle_outline,
                    size: 56,
                    color: bills.isEmpty ? Colors.grey : Colors.green.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    bills.isEmpty
                        ? 'No bills yet for this shop.'
                        : 'All settled — nothing pending.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ],
              ),
            ),
          );
        }

        final totalDue = open.fold<double>(0, (sum, b) => sum + b.amountDue);
        final daysOld = DateTime.now().difference(open.first.date).inDays;

        return Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${open.length} pending ${open.length == 1 ? 'bill' : 'bills'} · '
                      '${ref.watch(brandProvider).moneyDecimal(totalDue)} due',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  if (daysOld > 0)
                    Text(
                      'oldest ${daysOld}d',
                      style: TextStyle(fontSize: 11, color: Colors.red.shade400),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: open.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _OpenBillRow(entry: open[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── History ─────────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    final ledgerAsync = ref.watch(shopLedgerProvider((
      shopId: widget.shopId,
      range: _range,
      status: _statusFilter,
      type: _typeFilter,
    )));
    final hasFilters = _activeFilterCount > 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _openFilterSheet,
                icon: const Icon(Icons.tune, size: 16),
                label: Text(
                  hasFilters ? 'Filters ($_activeFilterCount)' : 'Filters',
                  style: const TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: hasFilters ? kBrandBrown : Colors.grey.shade700,
                  side: BorderSide(
                    color: hasFilters ? kBrandBrown : Colors.grey.shade300,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _filterSummary,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: hasFilters ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (hasFilters)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: Colors.grey.shade600,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Clear filters',
                  onPressed: _clearFilters,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ledgerAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (entries) {
              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    hasFilters
                        ? 'No entries match these filters.'
                        : 'No bills or payments yet.',
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _LedgerRow(
                    entry: entry,
                    onDelete: entry.type == LedgerType.payment
                        ? () => _confirmDeletePayment(entry)
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Filter sheet ──────────────────────────────────────────────────────────
// Three rows of chips crowded the list off the screen and read as clutter.
// One button, one summary line, and everything else behind a sheet.

class _LedgerFilterSheet extends StatefulWidget {
  const _LedgerFilterSheet({required this.initial});

  final LedgerFilters initial;

  @override
  State<_LedgerFilterSheet> createState() => _LedgerFilterSheetState();
}

class _LedgerFilterSheetState extends State<_LedgerFilterSheet> {
  DateTimeRange? _range;
  BillStatus? _status;
  LedgerType? _type;

  @override
  void initState() {
    super.initState();
    _range = widget.initial.range;
    _status = widget.initial.status;
    _type = widget.initial.type;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _range ??
          DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: kBrandBrown),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _range = picked);
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.grey.shade500,
          ),
        ),
      );

  Widget _choice<T>(String label, T value, T selected, ValueChanged<T> onPick) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected == value,
      onSelected: (_) => onPick(value),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Filters',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _range = null;
                  _status = null;
                  _type = null;
                }),
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _sectionLabel('Date range'),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(
                    _range == null
                        ? 'Any date'
                        : '${_dateFmt.format(_range!.start)} – ${_dateFmt.format(_range!.end)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              if (_range != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: Colors.grey.shade600,
                  tooltip: 'Clear date range',
                  onPressed: () => setState(() => _range = null),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _sectionLabel('Status'),
          Wrap(
            spacing: 8,
            children: [
              _choice('All', null, _status, (v) => setState(() => _status = v)),
              _choice('Unpaid', BillStatus.unpaid, _status,
                  (v) => setState(() => _status = v)),
              _choice('Partial', BillStatus.partial, _status,
                  (v) => setState(() => _status = v)),
              _choice('Paid', BillStatus.paid, _status,
                  (v) => setState(() => _status = v)),
            ],
          ),
          const SizedBox(height: 18),
          _sectionLabel('Type'),
          Wrap(
            spacing: 8,
            children: [
              _choice('All', null, _type, (v) => setState(() => _type = v)),
              _choice('Bills', LedgerType.bill, _type,
                  (v) => setState(() => _type = v)),
              _choice('Payments', LedgerType.payment, _type,
                  (v) => setState(() => _type = v)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                (range: _range, status: _status, type: _type),
              ),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsHeader extends ConsumerWidget {
  const _StatsHeader({required this.statsAsync});

  final AsyncValue<ShopLedgerStats> statsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: statsAsync.when(
        loading: () => const SizedBox(
          height: 64,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text('Error: $e'),
        data: (stats) => Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                      label: 'Total Billed', value: brand.moneyDecimal(stats.totalBilled)),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Total Collected',
                    value: brand.moneyDecimal(stats.totalCollected),
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Outstanding',
                    value: brand.moneyDecimal(stats.outstanding),
                    color: stats.outstanding > 0.005 ? Colors.red.shade700 : null,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Last Payment',
                    value: stats.lastPaymentAt != null
                        ? _dateFmt.format(stats.lastPaymentAt!)
                        : '—',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color ?? kBrandBrown,
          ),
        ),
      ],
    );
  }
}

/// A pending bill on the Outstanding tab: what the bill was, what has been paid
/// against it, and what is still due.
class _OpenBillRow extends ConsumerWidget {
  const _OpenBillRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    final partlyPaid = entry.allocatedAmount > 0.005;
    final daysOld = DateTime.now().difference(entry.date).inDays;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.receipt_long, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _dateFmt.format(entry.date),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: entry.billStatus!),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    'Bill ${brand.moneyDecimal(entry.amount)}',
                    if (partlyPaid) 'paid ${brand.moneyDecimal(entry.allocatedAmount)}',
                    if (daysOld > 0) '${daysOld}d ago',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Due',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
              Text(
                brand.moneyDecimal(entry.amountDue),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends ConsumerWidget {
  const _LedgerRow({required this.entry, this.onDelete});

  final LedgerEntry entry;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    final isBill = entry.type == LedgerType.bill;
    final amountColor = isBill ? Colors.red.shade700 : Colors.green.shade700;
    final subtitle = isBill
        ? 'Bill'
        : 'Payment · ${_modeLabel(entry.paymentMode!)}';
    final note = entry.note?.trim();

    return InkWell(
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isBill ? Icons.receipt_long : Icons.payments_outlined,
              color: amountColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _dateFmt.format(entry.date),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (isBill && entry.billStatus != null) ...[
                        const SizedBox(width: 8),
                        _StatusBadge(status: entry.billStatus!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (!isBill && (note?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 2),
                    Text(
                      note!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isBill ? 'Dr' : 'Cr'} ${brand.moneyDecimal(entry.amount)}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: amountColor),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bal ${brand.moneyDecimal(entry.runningBalance)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final BillStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color.shade700),
      ),
    );
  }
}
