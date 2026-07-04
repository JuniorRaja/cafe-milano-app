import 'dart:math';

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
                  Icon(_greetingIcon(), color: kBrandGold, size: 30),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'WELCOME BACK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        '${_greeting()}, $_greetingName',
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
      ),
    );
  }
}

const _greetingNames = ['Mohan', 'JMR'];
final _greetingName = _greetingNames[Random().nextInt(_greetingNames.length)];

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  return 'Good evening';
}

IconData _greetingIcon() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) return Icons.wb_sunny_rounded;
  if (hour >= 12 && hour < 17) return Icons.wb_cloudy_rounded;
  return Icons.nights_stay_rounded;
}
