import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/order_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/staggered_fade_in.dart';

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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _expandedOrderId = null;
      });
    }
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Billing',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Summary of all shop bills',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 14),
            label: Text(
              DateFormat('dd MMM yyyy').format(_date),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      body: summariesAsync.when(
        data: (summaries) {
          if (summaries.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: Colors.grey),
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
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  itemCount: summaries.length,
                  itemBuilder: (context, i) {
                    final s = summaries[i];
                    final shop = shopMap[s.order.shopId];
                    final isExpanded = _expandedOrderId == s.order.id;
                    return StaggeredFadeIn(
                      key: ValueKey(s.order.id),
                      index: i,
                      child: _OrderCard(
                        summary: s,
                        shop: shop,
                        index: i + 1,
                        productMap: productMap,
                        isExpanded: isExpanded,
                        onToggle: () => setState(() {
                          _expandedOrderId =
                              isExpanded ? null : s.order.id;
                        }),
                        onShare: () => _shareOne(s, shop, productMap),
                      ),
                    );
                  },
                ),
              ),
              // Floating grand total card
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    color: kBrandBrown,
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Grand Total',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                              Text(
                                '₹${NumberFormat('#,##0.##').format(grandTotal)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _shareAll(summaries, shopMap),
                            icon: const Icon(Icons.share,
                                size: 16, color: Colors.white),
                            label: const Text(
                              'Share All Bills',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
        final name =
            productMap[line.productId]?.name ?? 'Product #${line.productId}';
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.summary,
    required this.shop,
    required this.index,
    required this.productMap,
    required this.isExpanded,
    required this.onToggle,
    required this.onShare,
  });

  final OrderDaySummary summary;
  final Shop? shop;
  final int index;
  final Map<int, Product> productMap;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final isConfirmed = summary.order.isConfirmed;
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: kBrandBrown,
                    child: Text(
                      index.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
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
          AnimatedSize(
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? _BillingDetail(
                    orderId: summary.order.id, productMap: productMap)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
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
            child: Text('No items',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          );
        }
        final total =
            data.lines.fold<double>(0, (s, l) => s + l.qty * l.unitPrice);
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1),
              Container(
                color: const Color(0xFFFFF3E0),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
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
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ...data.lines.map((line) {
                final product = productMap[line.productId];
                final lineTotal = line.qty * line.unitPrice;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          product?.name ??
                              'Product #${line.productId}',
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
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 1, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        color: kBrandBrown,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₹${NumberFormat('#,##0').format(total)}',
                      style: const TextStyle(
                        color: kBrandBrown,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
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
        child: Text('Error: $e',
            style: const TextStyle(color: Colors.red)),
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
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
