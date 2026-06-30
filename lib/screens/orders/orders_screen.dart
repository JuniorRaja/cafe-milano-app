import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../database/app_database.dart';
import '../../providers/order_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/product_provider.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  late DateTime _date;
  int? _expandedOrderId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(orderSummariesForDateProvider(_date));
    final shopMap = ref.watch(allShopsProvider).maybeWhen(
      data: (shops) => {for (final s in shops) s.id: s},
      orElse: () => <int, Shop>{},
    );
    final productMap = ref.watch(allProductsProvider).maybeWhen(
      data: (products) => {for (final p in products) p.id: p},
      orElse: () => <int, Product>{},
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        children: [
          _DateRow(
            date: _date,
            onChanged: (d) => setState(() {
              _date = d;
              _expandedOrderId = null;
            }),
          ),
          const Divider(height: 1),
          Expanded(
            child: summariesAsync.when(
              data: (summaries) {
                if (summaries.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No orders for this date',
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                final grandTotal =
                    summaries.fold<double>(0, (s, e) => s + e.total);

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: summaries.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (context, i) {
                          final s = summaries[i];
                          final shop = shopMap[s.order.shopId];
                          final isExpanded = _expandedOrderId == s.order.id;
                          return _OrderRow(
                            key: ValueKey(s.order.id),
                            summary: s,
                            shop: shop,
                            productMap: productMap,
                            isExpanded: isExpanded,
                            onToggle: () => setState(() {
                              _expandedOrderId =
                                  isExpanded ? null : s.order.id;
                            }),
                            onShare: () => _shareOne(s, shop, productMap),
                          );
                        },
                      ),
                    ),
                    // Grand total sticky footer
                    SafeArea(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 8,
                              color: Colors.black.withAlpha(20),
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Grand Total: ₹${NumberFormat('#,##0.##').format(grandTotal)}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${summaries.length} shop${summaries.length != 1 ? 's' : ''}',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _shareAll(summaries, shopMap),
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('Share All'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareOne(
    OrderDaySummary summary,
    Shop? shop,
    Map<int, Product> productMap,
  ) async {
    final owl =
        await ref.read(orderWithLinesProvider(summary.order.id).future);
    final text = _buildBillText(shop?.name ?? 'Unknown', owl, productMap);
    await Share.share(text);
  }

  Future<void> _shareAll(
    List<OrderDaySummary> summaries,
    Map<int, Shop> shopMap,
  ) async {
    final dateLabel = DateFormat('dd MMM yyyy').format(_date);
    final buf = StringBuffer();
    buf.writeln('🧾 Bills — $dateLabel');
    buf.writeln();

    final maxLen = summaries
        .map((s) => shopMap[s.order.shopId]?.name.length ?? 0)
        .fold(0, max);

    for (final s in summaries) {
      final name = shopMap[s.order.shopId]?.name ?? 'Unknown';
      buf.writeln(
        '${name.padRight(maxLen + 2)}: ₹${NumberFormat('#,##0').format(s.total)}',
      );
    }

    buf.writeln();
    final grand = summaries.fold<double>(0, (a, b) => a + b.total);
    buf.writeln(
      '${'GRAND TOTAL'.padRight(maxLen + 2)}: ₹${NumberFormat('#,##0').format(grand)}',
    );

    await Share.share(buf.toString().trim());
  }

  String _buildBillText(
    String shopName,
    OrderWithLines? owl,
    Map<int, Product> productMap,
  ) {
    final dateLabel = DateFormat('dd MMM yyyy').format(_date);
    final buf = StringBuffer();
    buf.writeln('🧾 Bill — $shopName');
    buf.writeln('Date: $dateLabel');
    buf.writeln();

    if (owl != null && owl.lines.isNotEmpty) {
      final maxNameLen = owl.lines
          .map((l) => productMap[l.productId]?.name.length ?? 0)
          .fold(0, max);
      double total = 0;
      for (final line in owl.lines) {
        final name = productMap[line.productId]?.name ?? 'Product #${line.productId}';
        final lineTotal = line.qty * line.unitPrice;
        total += lineTotal;
        buf.writeln(
          '${name.padRight(maxNameLen + 2)}× ${line.qty.toString().padLeft(4)}  ₹${NumberFormat('#,##0').format(lineTotal)}',
        );
      }
      buf.writeln();
      buf.writeln('TOTAL: ₹${NumberFormat('#,##0').format(total)}');
    } else {
      buf.writeln('No items');
    }
    return buf.toString().trim();
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onChanged});

  final DateTime date;
  final void Function(DateTime) onChanged;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('dd MMM yyyy, EEE').format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(date.subtract(const Duration(days: 1))),
          ),
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) onChanged(picked);
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(date.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    super.key,
    required this.summary,
    required this.shop,
    required this.productMap,
    required this.isExpanded,
    required this.onToggle,
    required this.onShare,
  });

  final OrderDaySummary summary;
  final Shop? shop;
  final Map<int, Product> productMap;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final isConfirmed = summary.order.isConfirmed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop?.name ?? 'Shop #${summary.order.shopId}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      if (shop?.area != null)
                        Text(
                          shop!.area!,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${NumberFormat('#,##0').format(summary.total)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: isConfirmed ? 'Confirmed' : 'Pending',
                  color: isConfirmed ? Colors.green : Colors.grey,
                ),
                IconButton(
                  icon: const Icon(Icons.share, size: 20),
                  onPressed: onShare,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Share bill',
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          _BillingDetail(orderId: summary.order.id, productMap: productMap),
      ],
    );
  }
}

class _BillingDetail extends ConsumerWidget {
  const _BillingDetail({required this.orderId, required this.productMap});

  final int orderId;
  final Map<int, Product> productMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owlAsync = ref.watch(orderWithLinesProvider(orderId));
    return owlAsync.when(
      data: (data) {
        if (data == null || data.lines.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text('No items', style: TextStyle(color: Colors.grey, fontSize: 13)),
          );
        }
        final total = data.lines.fold<double>(0, (s, l) => s + l.qty * l.unitPrice);
        return Container(
          color: const Color(0xFFF5F5F5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Item',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey)),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text('Qty',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey),
                          textAlign: TextAlign.center),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text('Price',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey),
                          textAlign: TextAlign.right),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text('Total',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey),
                          textAlign: TextAlign.right),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ...data.lines.map((line) {
                final product = productMap[line.productId];
                final lineTotal = line.qty * line.unitPrice;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          product?.name ?? 'Product #${line.productId}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          line.qty.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: Text(
                          '₹${NumberFormat('#,##0.##').format(line.unitPrice)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: Text(
                          '₹${NumberFormat('#,##0').format(lineTotal)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 1, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total: ₹${NumberFormat('#,##0').format(total)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
