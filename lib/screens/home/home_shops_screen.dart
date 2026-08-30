
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/date_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/date_selector.dart';
import '../../widgets/shop_order_card.dart';
import '../../widgets/staggered_fade_in.dart';
import '../../widgets/shell/app_shell.dart';

class HomeShopsScreen extends ConsumerWidget {
  const HomeShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final shopsAsync = ref.watch(activeShopsProvider);
    final summariesAsync = ref.watch(orderSummariesForDateProvider(selectedDate));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        'TODAY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        'Orders',
                        style: const TextStyle(
                          fontSize: 24,
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
            const DateSelector(),
            Expanded(
              child: shopsAsync.when(
                data: (shops) {
                  final summaryMap = summariesAsync.maybeWhen(
                    data: (summaries) =>
                        {for (final s in summaries) s.order.shopId: s},
                    orElse: () => <int, OrderDaySummary>{},
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            Text(
                              'Shops',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              '${shops.length} shops',
                              style: const TextStyle(
                                color: kBrandBrown,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: shops.isEmpty
                            ? const _EmptyState()
                            : ListFadeIn(
                                child: ListView.builder(
                                itemCount: shops.length,
                                itemBuilder: (context, index) {
                                  final shop = shops[index];
                                  return RepaintBoundary(
                                    child: ShopOrderCard(
                                      shop: shop,
                                      summary: summaryMap[shop.id],
                                      onTap: () => context.push(
                                          AppRoutes.orderEntryFor(shop.id,
                                              date: selectedDate)),
                                    ),
                                  );
                                },
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


