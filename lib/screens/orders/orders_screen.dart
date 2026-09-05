import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../database/app_database.dart';
import '../../providers/date_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/read_once.dart';
import '../../providers/order_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/date_selector.dart';
import '../../services/bill_share.dart';
import '../ledger/record_payment_sheet.dart';
import '../../widgets/shell/app_shell.dart';
import '../../widgets/ui/ui.dart';
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

    return AppScaffold(
      caption: 'Daily billing',
      title: 'Shop Bills',
      leading: const ShellDrawerButton(),
      bottom: const DateSelector(),
      body: summariesAsync.when(
        data: (summaries) {
          if (summaries.isEmpty) {
            return const EmptyState.inert(
              icon: Icons.receipt_long_outlined,
              title: 'No bills for this date',
              message: 'Bills appear here once a shop has an order on this '
                  'day.',
            );
          }

          final grandTotal =
              summaries.fold<double>(0, (s, e) => s + e.total);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s4,
                    AppSpace.s2,
                    AppSpace.s4,
                    0,
                  ),
                  itemCount: summaries.length,
                  itemBuilder: (context, i) {
                    final s = summaries[i];
                    final shop = shopMap[s.order.shopId];
                    final isExpanded = _expandedOrderId == s.order.id;
                    return RepaintBoundary(
                      key: ValueKey(s.order.id),
                      child: _BillCard(
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
              // The day's figure, and the way bills leave the app.
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: AppCard(
                    color: AppColors.brandDeep,
                    shadow: AppShadow.raised,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s4,
                      vertical: AppSpace.s3,
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'GRAND TOTAL',
                              style: AppType.caption.copyWith(
                                color: AppColors.textOnDark,
                              ),
                            ),
                            Text(
                              ref.watch(brandProvider).moneyTrim(grandTotal),
                              style: AppType.titleM.copyWith(
                                color: AppColors.textOnDark,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => _shareBills(summaries, shopMap, date),
                          icon: const Icon(Icons.ios_share_rounded, size: 16),
                          label: const Text('Share bills'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textOnDark,
                            side: const BorderSide(color: AppColors.textOnDark),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.rS,
                            ),
                          ),
                        ),
                      ],
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
    await Share.share(billDetailText(
      shopName: shop?.name ?? 'Unknown',
      order: owl,
      productMap: productMap,
      brand: ref.read(brandProvider),
      dateLabel: DateFormat('dd MMM yyyy').format(date),
    ));
  }

  /// Ask which shops, then share those.
  ///
  /// It used to share every bill on the date with no way to narrow it, and the
  /// footer said `Share All Bills` because that is all it could do. The
  /// GRAND TOTAL is now the total of what was picked: a partial share carrying
  /// the whole day's figure is a wrong number sent to a customer.
  Future<void> _shareBills(
    List<OrderDaySummary> summaries,
    Map<int, Shop> shopMap,
    DateTime date,
  ) async {
    final brand = ref.read(brandProvider);

    final chosen = await showMultiSelectSheet(
      context,
      title: 'Share bills',
      noun: 'shops',
      options: [
        for (final s in summaries)
          SelectOption(
            id: s.order.id,
            title: shopMap[s.order.shopId]?.name ?? 'Shop #${s.order.shopId}',
            subtitle: shopMap[s.order.shopId]?.area,
            trailing: brand.money(s.total),
          ),
      ],
      confirmLabel: (count) =>
          'Share $count bill${count == 1 ? '' : 's'}',
    );
    // Null is a dismissed sheet, which is not the same as picking nothing.
    if (chosen == null) return;

    final picked =
        summaries.where((s) => chosen.contains(s.order.id)).toList();
    if (picked.isEmpty) return;

    await Share.share(billsSummaryText(
      bills: picked,
      shopMap: shopMap,
      brand: brand,
      dateLabel: DateFormat('dd MMM yyyy').format(date),
    ));
  }
}

/// One bill, in three rows.
///
/// It was one row: shop, area and total on the left, then two chips, a share
/// button and a caret squeezed into what was left. On a narrow phone with a
/// five-digit total that cluster did not fit, and the code worked around it
/// with a `FittedBox` that scaled the chips down until they did — so the
/// smaller the shop's bill, the more readable its status. The strip below the
/// hairline is that fix: the status has a line of its own, and the money keeps
/// the right-hand column to itself.
class _BillCard extends ConsumerWidget {
  const _BillCard({
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

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.s2),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.rM,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onToggle,
                onLongPress: settled ? null : onMarkPaid,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s4,
                    vertical: AppSpace.s3,
                  ),
                  child: Row(
                    children: [
                      _IndexDot(index: index),
                      const SizedBox(width: AppSpace.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              shop?.name ?? 'Shop #${summary.order.shopId}',
                              style: AppType.titleS,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (shop?.area != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                shop!.area!,
                                style: AppType.bodyS.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpace.s2),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(brand.money(summary.total),
                              style: AppType.titleS),
                          Text(
                            _secondLine(brand, due),
                            style: AppType.bodyS.copyWith(
                              color: settled
                                  ? AppColors.textTertiary
                                  : AppColors.negative,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                AppSpace.s1,
                AppSpace.s2,
                AppSpace.s1,
              ),
              child: Row(
                children: [
                  StatusBadge(
                    label: isConfirmed ? 'Confirmed' : 'Pending',
                    tone: isConfirmed ? AppTone.positive : AppTone.neutral,
                  ),
                  if (due != null) ...[
                    const SizedBox(width: AppSpace.s2),
                    // The badge is the discoverable half of Mark-as-Paid;
                    // long-pressing the card is the same action for anyone who
                    // reaches for that instead.
                    _Tappable(
                      onTap: settled ? null : onMarkPaid,
                      child: StatusBadge(
                        label: _payLabel(due.status),
                        tone: _payTone(due.status),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.ios_share_rounded, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: onShare,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Share bill',
                  ),
                  // The caret is the only thing on the card that says tapping
                  // it does anything, so it survived the move out of the
                  // trailing cluster.
                  IconButton(
                    icon: Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                    ),
                    color: AppColors.textSecondary,
                    onPressed: onToggle,
                    visualDensity: VisualDensity.compact,
                    tooltip: isExpanded ? 'Hide items' : 'Show items',
                  ),
                ],
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
      ),
    );
  }

  /// Under the total: what is still owed, or how big the order was. A bill
  /// that is settled has no outstanding figure to show, and printing `₹0 due`
  /// on every paid row would bury the ones that are not.
  String _secondLine(BrandConfig brand, BillDue? due) {
    if (due != null && due.status != BillStatus.paid && due.amountDue > 0) {
      return '${brand.money(due.amountDue)} due';
    }
    return '${summary.itemCount} item${summary.itemCount == 1 ? '' : 's'}';
  }
}

/// The bill's position in the day's list.
class _IndexDot extends StatelessWidget {
  const _IndexDot({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$index',
        style: AppType.label.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

/// An ink ripple clipped to a pill, for a badge that is also a button.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rFull,
        child: child,
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
        // The card clips its own corners now, so this only needs a ground.
        return ColoredBox(
          color: AppColors.surface,
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
                    Text(
                      'Total',
                      style: AppType.titleS
                          .copyWith(color: AppColors.brandDeep),
                    ),
                    const Spacer(),
                    Text(
                      brand.money(total),
                      style: AppType.titleS
                          .copyWith(color: AppColors.brandDeep),
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

AppTone _payTone(BillStatus status) => switch (status) {
      BillStatus.paid => AppTone.positive,
      BillStatus.partial => AppTone.warning,
      BillStatus.unpaid => AppTone.negative,
    };
