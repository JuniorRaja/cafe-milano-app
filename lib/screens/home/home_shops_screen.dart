import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/date_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/error_reporting.dart';
import '../../providers/order_provider.dart';
import '../../theme/brand_config.dart';
import '../../utils/money.dart';
import '../../widgets/date_selector.dart';
import '../../widgets/letter_avatar.dart';
import '../../widgets/staggered_fade_in.dart';
import '../../widgets/shell/app_shell.dart';
import '../../widgets/ui/ui.dart';

class HomeShopsScreen extends ConsumerStatefulWidget {
  const HomeShopsScreen({super.key});

  @override
  ConsumerState<HomeShopsScreen> createState() => _HomeShopsScreenState();
}

class _HomeShopsScreenState extends ConsumerState<HomeShopsScreen> {
  /// 0 All, 1 Confirmed, 2 Pending. Index rather than an enum because
  /// `FilterChipRow` is index-driven and a two-value enum here would exist
  /// only to be converted back.
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    // One provider, one `.when`. The summaries used to arrive through
    // `maybeWhen(orElse: () => {})`, so a failed query drew every shop as
    // *not yet ordered* — an invitation to enter every order twice. See
    // `homeViewProvider`.
    final viewAsync = ref.watch(homeViewProvider(selectedDate));

    return AppScaffold(
      caption: 'Today',
      title: 'Orders',
      leading: const ShellDrawerButton(),
      bottom: const DateSelector(),
      body: viewAsync.when(
        data: (view) {
          final shops = view.shops;
          final summaryMap = view.summaryMap;

          // The question this screen exists to answer is "which shops still
          // need an order today", and until now you answered it by scrolling.
          // `Confirmed` and `Pending`, not the doc's `Ordered`, because that
          // is the word `_ShopRow`'s badge already uses — one state should not
          // have two names on the same screen.
          final confirmed = shops
              .where((s) => summaryMap[s.id]?.order.isConfirmed ?? false)
              .length;
          final pending = shops.length - confirmed;
          final visible = switch (_filter) {
            1 => shops
                .where((s) => summaryMap[s.id]?.order.isConfirmed ?? false)
                .toList(),
            2 => shops
                .where((s) => !(summaryMap[s.id]?.order.isConfirmed ?? false))
                .toList(),
            _ => shops,
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // No StatBand here. The chips below already carry both counts,
              // and a band repeating them cost a whole band of screen on a
              // list whose job is to be long — the owner asked for it back.
              if (shops.isNotEmpty)
                FilterChipRow(
                  chips: [
                    FilterChipData('All', count: shops.length),
                    FilterChipData(
                      'Confirmed',
                      count: confirmed,
                      tone: AppTone.positive,
                    ),
                    FilterChipData(
                      'Pending',
                      count: pending,
                      tone: AppTone.warning,
                    ),
                  ],
                  selectedIndex: _filter,
                  onSelected: (i) => setState(() => _filter = i),
                ),
              Expanded(
                child: shops.isEmpty
                    ? _EmptyState(
                        onAddShop: () => context.push(AppRoutes.shopNew),
                      )
                    : visible.isEmpty
                    ? EmptyState.inert(
                        icon: Icons.filter_alt_off_outlined,
                        title: _filter == 1
                            ? 'Nothing confirmed yet'
                            : 'Every shop is done',
                        message: _filter == 1
                            ? 'No shop has a confirmed order for this date.'
                            : 'Every shop has a confirmed order for this date.',
                      )
                    : ListFadeIn(
                        child: ListView.builder(
                          // The nav bar floats over the body now. See
                          // `AppShell.bottomInset`.
                          padding: EdgeInsets.only(
                            bottom: AppShell.bottomInset(context),
                          ),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final shop = visible[index];
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
        error: (e, st) {
          reportError(e, st, context: 'home/orders');
          return AppErrorView(
            message: "Could not load today's orders.",
            cause: '$e',
            onRetry: () {
              ref.invalidate(activeShopsProvider);
              ref.invalidate(orderSummariesForDateProvider(selectedDate));
            },
          );
        },
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
      trailing: order == null
          ? null
          : ref.watch(brandProvider).money(order.total),
      trailingSubtitle: order == null ? null : '${order.itemCount} items',
      onTap: onTap,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddShop});

  final VoidCallback onAddShop;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.storefront_outlined,
      title: 'No shops yet',
      message: 'Add a shop and it will appear here every morning.',
      actionLabel: 'Add your first shop',
      onAction: onAddShop,
    );
  }
}
