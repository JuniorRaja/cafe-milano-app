
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/date_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/order_provider.dart';
import '../../theme/brand_config.dart';
import '../../utils/money.dart';
import '../../widgets/date_selector.dart';
import '../../widgets/letter_avatar.dart';
import '../../widgets/staggered_fade_in.dart';
import '../../widgets/shell/app_shell.dart';
import '../../widgets/ui/ui.dart';

class HomeShopsScreen extends ConsumerWidget {
  const HomeShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final shopsAsync = ref.watch(activeShopsProvider);
    final summariesAsync = ref.watch(orderSummariesForDateProvider(selectedDate));

    return AppScaffold(
      caption: 'Today',
      title: 'Orders',
      leading: const ShellDrawerButton(),
      bottom: const DateSelector(),
      body: shopsAsync.when(
        data: (shops) {
          final summaryMap = summariesAsync.maybeWhen(
            data: (summaries) => {for (final s in summaries) s.order.shopId: s},
            orElse: () => <int, OrderDaySummary>{},
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Shops',
                trailing: Text(
                  '${shops.length} shops',
                  style: AppType.label.copyWith(color: AppColors.brandDeep),
                ),
              ),
              Expanded(
                child: shops.isEmpty
                    ? const _EmptyState()
                    : ListFadeIn(
                        child: ListView.builder(
                          // The nav bar floats over the body now. See
                          // `AppShell.bottomInset`.
                          padding: EdgeInsets.only(
                            bottom: AppShell.bottomInset(context),
                          ),
                          itemCount: shops.length,
                          itemBuilder: (context, index) {
                            final shop = shops[index];
                            return _ShopRow(
                              shop: shop,
                              summary: summaryMap[shop.id],
                              onTap: () => context.push(
                                AppRoutes.orderEntryFor(
                                  shop.id,
                                  date: selectedDate,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

/// One shop, two lines, the way the owner drew it on the device pass:
///
/// ```
/// | (avatar)  Shop Title  (mark)             ₹ amount |
/// |           Location                        N items |
/// ```
///
/// It replaces `ShopOrderCard`, which spent a 16-padded card, an avatar, a
/// title, an area row and a chip row on the same information at roughly twice
/// the height. This is [ListRow], so it is the same row the ledger, the
/// masters and Outstanding already use — money in one straight right-hand
/// column down the list, which is the decision commit `762be58` recorded and
/// the reason it reads at 5 a.m.
class _ShopRow extends ConsumerWidget {
  const _ShopRow({
    required this.shop,
    required this.summary,
    required this.onTap,
  });

  final Shop shop;
  final OrderDaySummary? summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = summary;
    final confirmed = order?.order.isConfirmed ?? false;

    return ListRow(
      title: shop.name,
      // The second line is the area, as the owner drew it. The hint only
      // appears when there is nothing else to put there — a shop with no area
      // *and* no order. Everywhere else the amber mark and the empty money
      // column already say the order is missing, and the whole row is the tap
      // target, so spending the line on an instruction would cost real
      // information to repeat something visible.
      subtitle: shop.area ?? (order == null ? 'Tap to add order' : null),
      subtitleIcon: shop.area == null ? null : Icons.place_outlined,
      leading: LetterAvatar(name: shop.name, radius: 20),
      titleBadge: confirmed
          ? const StatusBadge.mark(
              icon: Icons.check_circle_rounded,
              label: 'Confirmed',
              tone: AppTone.positive,
            )
          : const StatusBadge.mark(
              icon: Icons.warning_rounded,
              label: 'Pending',
              tone: AppTone.warning,
            ),
      // Null, never a formatted zero. `₹0` on a shop with no order reads as a
      // real zero-rupee order, which is a different and much worse thing.
      trailing: order == null ? null : ref.watch(brandProvider).money(order.total),
      trailingSubtitle: order == null ? null : '${order.itemCount} items',
      onTap: onTap,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No shops yet',
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }
}


