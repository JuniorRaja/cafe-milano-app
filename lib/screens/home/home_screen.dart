import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../providers/date_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/date_selector.dart';
import '../../widgets/shop_order_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final shopsAsync = ref.watch(activeShopsProvider);
    final summariesAsync = ref.watch(orderSummariesForDateProvider(selectedDate));

    return Scaffold(
      appBar: AppBar(title: const Text('BakeOrder')),
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
                      child: Text(
                        'Shops · ${shops.length} shops',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: shops.length,
                        itemBuilder: (context, index) {
                          final shop = shops[index];
                          return ShopOrderCard(
                            shop: shop,
                            summary: summaryMap[shop.id],
                            onTap: () => context
                                .push('/order/${shop.id}?date=$dateStr'),
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
