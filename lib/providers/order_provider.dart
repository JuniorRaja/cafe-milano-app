import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'category_provider.dart';
import 'combine.dart';
import 'database_provider.dart';
import 'ledger_provider.dart';
import 'product_provider.dart';
import 'shop_provider.dart';

final ordersForDateProvider = StreamProvider.autoDispose
    .family<List<DailyOrder>, DateTime>((ref, date) {
      return ref.watch(databaseProvider).orderDao.watchShopOrdersForDate(date);
    });

final orderWithLinesProvider = StreamProvider.autoDispose
    .family<OrderWithLines?, int>((ref, orderId) {
      return ref.watch(databaseProvider).orderDao.watchOrderWithLines(orderId);
    });

final orderSummariesForDateProvider = StreamProvider.autoDispose
    .family<List<OrderDaySummary>, DateTime>((ref, date) {
      return ref
          .watch(databaseProvider)
          .orderDao
          .watchOrderSummariesForDate(date);
    });

final kitchenLinesForDateProvider = StreamProvider.autoDispose
    .family<List<KitchenRawLine>, DateTime>((ref, date) {
      return ref
          .watch(databaseProvider)
          .orderDao
          .watchKitchenLinesForDate(date);
    });

// ---------------------------------------------------------------------------
// Composed screen views
// ---------------------------------------------------------------------------

/// Everything the Kitchen screen draws, as one `AsyncValue`.
typedef KitchenView = ({
  List<KitchenRawLine> lines,
  Map<int, Shop> shopMap,
  Map<int, Product> productMap,
  List<Category> categories,
});

/// The Kitchen screen reads this instead of four providers.
///
/// It used to read all four with `maybeWhen(orElse: () => [])`. A failed
/// products or lines query therefore produced an empty list, which the screen
/// drew as "No orders for this date" — the operator was told there was nothing
/// to bake because the database had failed. One `AsyncValue` means one loading
/// state, one error state, one data state.
final kitchenViewProvider = Provider.autoDispose
    .family<AsyncValue<KitchenView>, DateTime>((ref, date) {
      final lines = ref.watch(kitchenLinesForDateProvider(date));
      final shops = ref.watch(allShopsProvider);
      final products = ref.watch(allProductsProvider);
      final categories = ref.watch(allCategoriesProvider);

      return combineAsync(
        [lines, shops, products, categories],
        () => (
          lines: lines.requireValue,
          shopMap: {for (final s in shops.requireValue) s.id: s},
          productMap: {for (final p in products.requireValue) p.id: p},
          categories: categories.requireValue,
        ),
      );
    });

/// Everything the Home (Orders) screen draws, as one `AsyncValue`.
typedef HomeView = ({List<Shop> shops, Map<int, OrderDaySummary> summaryMap});

/// The Home screen reads this instead of two providers.
///
/// The summaries used to come through `maybeWhen(orElse: () => {})`. A failed
/// summary query therefore produced an empty map, and every shop in the list
/// drew as *not yet ordered* — which at 5 a.m. is an invitation to enter every
/// order a second time. Shops and summaries now fail together or not at all.
final homeViewProvider = Provider.autoDispose
    .family<AsyncValue<HomeView>, DateTime>((ref, date) {
      final shops = ref.watch(activeShopsProvider);
      final summaries = ref.watch(orderSummariesForDateProvider(date));

      return combineAsync(
        [shops, summaries],
        () => (
          shops: shops.requireValue,
          summaryMap: {
            for (final s in summaries.requireValue) s.order.shopId: s,
          },
        ),
      );
    });

/// Everything the Billing screen draws, as one `AsyncValue`.
typedef BillingView = ({
  List<OrderDaySummary> summaries,
  Map<int, Shop> shopMap,
  Map<int, Product> productMap,
  Map<int, BillDue> billDues,
});

/// The Billing screen reads this instead of four providers.
///
/// `billDues` is the one that mattered: read through
/// `maybeWhen(orElse: () => {})`, a failed query made every bill's due null,
/// so paid bills drew as unpaid and "Mark paid" appeared on bills that were
/// already settled. A money figure must never come from a fallback that also
/// means "the query failed".
final billingViewProvider = Provider.autoDispose
    .family<AsyncValue<BillingView>, DateTime>((ref, date) {
      final summaries = ref.watch(orderSummariesForDateProvider(date));
      final shops = ref.watch(allShopsProvider);
      final products = ref.watch(allProductsProvider);
      final dues = ref.watch(billDuesForDateProvider(date));

      return combineAsync(
        [summaries, shops, products, dues],
        () => (
          summaries: summaries.requireValue,
          shopMap: {for (final s in shops.requireValue) s.id: s},
          productMap: {for (final p in products.requireValue) p.id: p},
          billDues: dues.requireValue,
        ),
      );
    });
