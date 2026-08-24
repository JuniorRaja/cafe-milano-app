import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../database/app_database.dart';
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

class _ShopLedgerScreenState extends ConsumerState<ShopLedgerScreen> {
  DateTimeRange? _range;
  BillStatus? _statusFilter;
  LedgerType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(shopByIdProvider(widget.shopId)).value;
    final statsAsync = ref.watch(shopStatsProvider(widget.shopId));
    final query = (
      shopId: widget.shopId,
      range: _range,
      status: _statusFilter,
      type: _typeFilter,
    );
    final ledgerAsync = ref.watch(shopLedgerProvider(query));
    final hasFilters = _range != null || _statusFilter != null || _typeFilter != null;

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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => RecordPaymentSheet(shopId: widget.shopId),
        ),
        backgroundColor: kBrandGold,
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Record Payment'),
      ),
      body: Column(
        children: [
          _StatsHeader(statsAsync: statsAsync),
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
                  itemBuilder: (context, index) => _LedgerRow(entry: entries[index]),
                );
              },
            ),
          ),
        ],
      ),
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

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final isBill = entry.type == LedgerType.bill;
    final amountColor = isBill ? Colors.red.shade700 : Colors.green.shade700;
    final description = isBill
        ? 'Bill · ${_dateFmt.format(entry.date)}'
        : 'Payment · ${_modeLabel(entry.paymentMode!)}';

    return Padding(
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
                Text(description, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (isBill && entry.billStatus != null) ...[
                  const SizedBox(height: 4),
                  _StatusBadge(status: entry.billStatus!),
                ] else if (!isBill && (entry.note?.trim().isNotEmpty ?? false)) ...[
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
        ],
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
