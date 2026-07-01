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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final shopsAsync = ref.watch(activeShopsProvider);
    final summariesAsync = ref.watch(orderSummariesForDateProvider(selectedDate));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: kBrandGold,
              child: const Icon(Icons.bakery_dining,
                  color: Colors.black87, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Bake',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      TextSpan(
                        text: 'Order',
                        style: TextStyle(
                          color: kBrandBrown,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Manage orders from all shops',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: null,
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: kBrandBrown,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tap a shop card to enter an order'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        backgroundColor: kBrandGold,
        foregroundColor: Colors.black87,
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DateSelector(),
          const Divider(height: 1),
          Expanded(
            child: shopsAsync.when(
              data: (shops) {
                final summaryMap = summariesAsync.maybeWhen(
                  data: (summaries) =>
                      {for (final s in summaries) s.order.shopId: s},
                  orElse: () => <int, OrderDaySummary>{},
                );
                final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
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
                      child: ListView.builder(
                        itemCount: shops.length,
                        itemBuilder: (context, index) {
                          final shop = shops[index];
                          return StaggeredFadeIn(
                            index: index,
                            child: ShopOrderCard(
                              shop: shop,
                              summary: summaryMap[shop.id],
                              onTap: () => context
                                  .push('/order/${shop.id}?date=$dateStr'),
                            ),
                          );
                        },
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
}
