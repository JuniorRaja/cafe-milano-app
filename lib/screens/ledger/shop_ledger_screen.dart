import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/shop_provider.dart';
import 'record_payment_sheet.dart';

final _dateFmt = DateFormat('dd MMM yyyy');

String _fmtMoney(double v) => '₹${v.toStringAsFixed(2)}';

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

  void _openPaymentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecordPaymentSheet(shopId: widget.shopId),
    );
  }

  // Editing a payment is deliberately not supported — a payment's allocations
  // are derived, so re-pointing them safely means recomputing FIFO anyway.
  // Delete and re-record is the correction path.
  Future<void> _confirmDeletePayment(LedgerEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text(
          'Delete the ${_fmtMoney(entry.amount)} payment dated '
          '${_dateFmt.format(entry.date)}?\n\n'
          'Any bills it settled go back to unpaid. To correct a payment, '
          'delete it and record it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
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
            Text(shop?.name ?? 'Shop Ledger',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (shop?.area != null)
              Text(
                shop!.area!,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.normal),
              ),
          ],
        ),
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
        final oldest = open.first.date;
        final daysOld = DateTime.now().difference(oldest).inDays;

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
                      '${_fmtMoney(totalDue)} due',
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
    final hasFilters =
        _range != null || _statusFilter != null || _typeFilter != null;

    return Column(
      children: [
        _FiltersBar(
          range: _range,
          statusFilter: _statusFilter,
          typeFilter: _typeFilter,
          onRangeChanged: (v) => setState(() => _range = v),
          onStatusChanged: (v) => setState(() => _statusFilter = v),
          onTypeChanged: (v) => setState(() => _typeFilter = v),
        ),
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

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.statsAsync});

  final AsyncValue<ShopLedgerStats> statsAsync;

  @override
  Widget build(BuildContext context) {
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
                      label: 'Total Billed', value: _fmtMoney(stats.totalBilled)),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Total Collected',
                    value: _fmtMoney(stats.totalCollected),
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
                    value: _fmtMoney(stats.outstanding),
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

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.range,
    required this.statusFilter,
    required this.typeFilter,
    required this.onRangeChanged,
    required this.onStatusChanged,
    required this.onTypeChanged,
  });

  final DateTimeRange? range;
  final BillStatus? statusFilter;
  final LedgerType? typeFilter;
  final ValueChanged<DateTimeRange?> onRangeChanged;
  final ValueChanged<BillStatus?> onStatusChanged;
  final ValueChanged<LedgerType?> onTypeChanged;

  Future<void> _pickRange(BuildContext context) async {
    if (range != null) {
      onRangeChanged(null);
      return;
    }
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: kBrandBrown),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onRangeChanged(picked);
  }

  Widget _chip<T>(String label, T value, T selected, ValueChanged<T> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected == value,
        onSelected: (_) => onChanged(value),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: FilterChip(
            avatar: const Icon(Icons.date_range, size: 16),
            label: Text(
              range == null
                  ? 'Date Range'
                  : '${_dateFmt.format(range!.start)} – ${_dateFmt.format(range!.end)}',
              style: const TextStyle(fontSize: 12),
            ),
            selected: range != null,
            onSelected: (_) => _pickRange(context),
            visualDensity: VisualDensity.compact,
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _chip('All', null, statusFilter, onStatusChanged),
              _chip('Unpaid', BillStatus.unpaid, statusFilter, onStatusChanged),
              _chip('Partial', BillStatus.partial, statusFilter, onStatusChanged),
              _chip('Paid', BillStatus.paid, statusFilter, onStatusChanged),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _chip('All', null, typeFilter, onTypeChanged),
              _chip('Bills', LedgerType.bill, typeFilter, onTypeChanged),
              _chip('Payments', LedgerType.payment, typeFilter, onTypeChanged),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// A pending bill on the Outstanding tab: what the bill was, what has been paid
/// against it, and what is still due.
class _OpenBillRow extends StatelessWidget {
  const _OpenBillRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      _dateFmt.format(entry.date),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (daysOld > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${daysOld}d ago',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  partlyPaid
                      ? 'Bill ${_fmtMoney(entry.amount)} · paid ${_fmtMoney(entry.allocatedAmount)}'
                      : 'Bill ${_fmtMoney(entry.amount)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                _StatusBadge(status: entry.billStatus!),
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
                _fmtMoney(entry.amountDue),
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

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, this.onDelete});

  final LedgerEntry entry;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isBill = entry.type == LedgerType.bill;
    final amountColor = isBill ? Colors.red.shade700 : Colors.green.shade700;
    final description = isBill
        ? 'Bill · ${_dateFmt.format(entry.date)}'
        : 'Payment · ${_modeLabel(entry.paymentMode!)}';

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
                  Text(_dateFmt.format(entry.date),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 2),
                  Text(description,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (isBill && entry.billStatus != null) ...[
                    const SizedBox(height: 4),
                    _StatusBadge(status: entry.billStatus!),
                  ] else if (!isBill &&
                      (entry.note?.trim().isNotEmpty ?? false)) ...[
                    const SizedBox(height: 2),
                    Text(entry.note!,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isBill ? 'Dr' : 'Cr'} ${_fmtMoney(entry.amount)}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: amountColor),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bal ${_fmtMoney(entry.runningBalance)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            if (onDelete != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.grey.shade500,
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
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
    final MaterialColor color = switch (status) {
      BillStatus.paid => Colors.green,
      BillStatus.partial => Colors.orange,
      BillStatus.unpaid => Colors.red,
    };
    final label = switch (status) {
      BillStatus.paid => 'Paid',
      BillStatus.partial => 'Partial',
      BillStatus.unpaid => 'Unpaid',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.shade700),
      ),
    );
  }
}
