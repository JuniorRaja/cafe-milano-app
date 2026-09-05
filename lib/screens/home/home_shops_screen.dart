
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/date_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/date_selector.dart';
import '../../widgets/shop_order_card.dart';
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
                          itemCount: shops.length,
                          itemBuilder: (context, index) {
                            final shop = shops[index];
                            return RepaintBoundary(
                              child: ShopOrderCard(
                                shop: shop,
                                summary: summaryMap[shop.id],
                                onTap: () => context.push(
                                  AppRoutes.orderEntryFor(
                                    shop.id,
                                    date: selectedDate,
                                  ),
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


