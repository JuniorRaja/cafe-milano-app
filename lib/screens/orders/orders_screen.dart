import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/date_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/read_once.dart';
import '../../providers/order_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/date_selector.dart';
import '../../widgets/staggered_fade_in.dart';
import '../ledger/record_payment_sheet.dart';
import '../../widgets/shell/app_shell.dart';
import '../../utils/money.dart';
import '../../theme/brand_config.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  int? _expandedOrderId;

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(selectedDateProvider);
    final summariesAsync = ref.watch(orderSummariesForDateProvider(date));
    final shopMap = ref.watch(allShopsProvider).maybeWhen(
      data: (shops) => {for (final s in shops) s.id: s},
      orElse: () => <int, Shop>{},
    );
    final productMap = ref.watch(allProductsProvider).maybeWhen(
      data: (products) => {for (final p in products) p.id: p},
      orElse: () => <int, Product>{},
    );
    // One watched query for every bill on this date. Per-row lookups would be
    // an N+1, and a one-shot read would leave the chips stale until restart.
    final billDues = ref.watch(billDuesForDateProvider(date)).maybeWhen(
      data: (dues) => dues,
      orElse: () => <int, BillDue>{},
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const ShellDrawerButton(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DAILY BILLING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Text(
                        'Shop Bills',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: kBrandBrown,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Date selector
            const DateSelector(),
            // Content
            Expanded(
              child: summariesAsync.when(
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
                                billDue: billDues[s.order.id],
                                onMarkPaid: () => _markPaid(s, billDues[s.order.id]),
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
                                        ref.watch(brandProvider).moneyTrim(grandTotal),
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
                                        _shareAll(summaries, shopMap, date),
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
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the payment sheet for one bill, prefilled with what that bill still
  /// owes and pinned to it, so a shop paying its bill on the day is two taps
  /// rather than a trip through the ledger screen.
  void _markPaid(OrderDaySummary summary, BillDue? due) {
    if (due == null || due.status == BillStatus.paid) return;
    unawaited(showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Daily Billing sits inside the shell, which draws the nav bar and the
      // dashboard FAB above its body — so a sheet on the branch navigator comes
      // up *under* that FAB. The root navigator puts it above everything.
      useRootNavigator: true,
      builder: (_) => RecordPaymentSheet(
        shopId: summary.order.shopId,
        pinned: (
          orderId: summary.order.id,
          date: summary.order.orderDate,
          amountDue: due.amountDue,
        ),
      ),
    ));
  }

  Future<void> _shareOne(
    OrderDaySummary summary,
    Shop? shop,
    Map<int, Product> productMap,
  ) async {
    final date = ref.read(selectedDateProvider);
    final owl =
        await ref.readStreamOnce(orderWithLinesProvider(summary.order.id));
    final text = _buildBillText(shop?.name ?? 'Unknown', owl, productMap, date);
    await Share.share(text);
  }

  Future<void> _shareAll(
    List<OrderDaySummary> summaries,
    Map<int, Shop> shopMap,
    DateTime date,
  ) async {
    final brand = ref.read(brandProvider);
    final dateLabel = DateFormat('dd MMM yyyy').format(date);
    final buf = StringBuffer();
    buf.writeln('🧾 Bills — $dateLabel');
    buf.writeln();
    for (final s in summaries) {
      final name = shopMap[s.order.shopId]?.name ?? 'Unknown';
      buf.writeln('🏪 $name — ${brand.money(s.total)}');
    }
    buf.writeln();
    final grand = summaries.fold<double>(0, (a, b) => a + b.total);
    buf.writeln('GRAND TOTAL: ${brand.money(grand)}');
    await Share.share(buf.toString().trim());
  }

  String _buildBillText(
    String shopName,
    OrderWithLines? owl,
    Map<int, Product> productMap,
    DateTime date,
  ) {
    final brand = ref.read(brandProvider);
    final dateLabel = DateFormat('dd MMM yyyy').format(date);
    final buf = StringBuffer();
    buf.writeln('🧾 Bill — $shopName');
    buf.writeln('Date: $dateLabel');
    buf.writeln();
    if (owl != null && owl.lines.isNotEmpty) {
      final sorted = [...owl.lines]..sort((a, b) {
          final na = productMap[a.productId]?.name.toLowerCase() ?? '';
          final nb = productMap[b.productId]?.name.toLowerCase() ?? '';
          return na.compareTo(nb);
        });
      double total = 0;
      for (final line in sorted) {
        final name =
            productMap[line.productId]?.name ?? 'Product #${line.productId}';
        final lineTotal = line.qty * line.unitPrice;
        total += lineTotal;
        buf.writeln(
            '· $name × ${line.qty} — ${brand.money(lineTotal)}');
      }
      buf.writeln();
      buf.writeln('TOTAL: ${brand.money(total)}');
    } else {
      buf.writeln('No items');
    }
    return buf.toString().trim();
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({
    required this.summary,
    required this.shop,
    required this.index,
    required this.productMap,
    required this.billDue,
    required this.onMarkPaid,
    required this.isExpanded,
    required this.onToggle,
    required this.onShare,
  });

  final OrderDaySummary summary;
  final Shop? shop;
  final int index;
  final Map<int, Product> productMap;

  /// Null when this order is not a bill the ledger tracks — an empty order, or
  /// one dated before its shop's opening-balance cutoff. No chip for those.
  final BillDue? billDue;
  final VoidCallback onMarkPaid;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    final isConfirmed = summary.order.isConfirmed;
    final due = billDue;
    final settled = due == null || due.status == BillStatus.paid;
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
            onLongPress: settled ? null : onMarkPaid,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              brand.money(summary.total),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const Spacer(),
                            // Two chips, a share button and a caret is more
                            // than a narrow phone fits beside a five-digit
                            // total, so the trailing cluster shrinks to fit
                            // rather than overflowing the card.
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (due != null) ...[
                                      _StatusChip(
                                        label: _payLabel(due.status),
                                        color: _payColor(due.status),
                                        // The chip is the discoverable half of
                                        // Mark-as-Paid; long-pressing the card
                                        // is the same action for anyone who
                                        // reaches for that instead.
                                        onTap: settled ? null : onMarkPaid,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
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
                                      isExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
    final brand = ref.watch(brandProvider);
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
                          brand.moneyTrim(line.unitPrice),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: Text(
                          brand.money(lineTotal),
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
                      brand.money(total),
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

String _payLabel(BillStatus status) => switch (status) {
      BillStatus.paid => 'Paid',
      BillStatus.partial => 'Partial',
      BillStatus.unpaid => 'Unpaid',
    };

Color _payColor(BillStatus status) => switch (status) {
      BillStatus.paid => Colors.green,
      BillStatus.partial => Colors.orange,
      BillStatus.unpaid => Colors.red,
    };

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color, this.onTap});
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
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

    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: chip,
    );
  }
}
