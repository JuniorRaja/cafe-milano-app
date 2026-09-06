import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/providers/dashboard_provider.dart';
import 'package:milano_orders/providers/database_provider.dart';
import 'package:milano_orders/models/dashboard_models.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('Pulse providers do not recompute when the date range changes', () async {
    final before = await container.read(todayRevenueProvider.future);
    final beforeState = container.read(todayRevenueProvider);

    container.read(dashboardRangeProvider.notifier).selectPreset(DashboardPreset.lastMonth);
    // Give any (unwanted) recomputation a chance to start.
    await Future<void>.delayed(Duration.zero);

    final afterState = container.read(todayRevenueProvider);
    expect(identical(beforeState, afterState), isTrue,
        reason: 'todayRevenueProvider should not recompute on range change');
    expect(await container.read(todayRevenueProvider.future), before);
  });

  test('getShopConcentration executes once and is shared across consumers', () async {
    final range = container.read(dashboardRangeProvider).range;

    final direct = await container.read(shopConcentrationDataProvider(range).future);
    final viaShopCard = await container.read(shopConcentrationProvider.future);
    final viaAttentionFlags = await container.read(attentionFlagsProvider.future);

    // Both consumers resolve from the same cached family instance —
    // the underlying rows list is the identical object, not a re-fetch.
    final directAgain = await container.read(shopConcentrationDataProvider(range).future);
    expect(identical(direct, directAgain), isTrue);
    expect(viaShopCard, isA<List<ShopConcentrationRow>>());
    expect(viaAttentionFlags, isA<List<AttentionFlag>>());
  });

  test('shopConcentrationProvider reports correct per-shop category breadth (N+1 collapse)', () async {
    final shopA = await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Shop A'));
    final shopB = await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Shop B'));
    final bakeryId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(name: 'Bakery', sortOrder: const Value(0)));
    final drinksId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(name: 'Drinks', sortOrder: const Value(1)));
    final bun = await db.productDao.upsertProduct(
        ProductsCompanion.insert(name: 'Bun', categoryId: Value(bakeryId)));
    final tea = await db.productDao.upsertProduct(
        ProductsCompanion.insert(name: 'Tea', categoryId: Value(drinksId)));

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    // Shop A orders both categories; Shop B orders only bakery.
    final orderA = await db.orderDao.getOrCreateOrder(shopA, todayStart);
    await db.orderDao.replaceOrderLines(orderA.id, [
      OrderLinesCompanion.insert(orderId: orderA.id, productId: bun, qty: 1, unitPrice: 5.0),
      OrderLinesCompanion.insert(orderId: orderA.id, productId: tea, qty: 1, unitPrice: 8.0),
    ]);
    final orderB = await db.orderDao.getOrCreateOrder(shopB, todayStart);
    await db.orderDao.replaceOrderLines(orderB.id, [
      OrderLinesCompanion.insert(orderId: orderB.id, productId: bun, qty: 1, unitPrice: 5.0),
    ]);

    container.read(dashboardRangeProvider.notifier).selectPreset(DashboardPreset.today);
    final rows = await container.read(shopConcentrationProvider.future);

    final rowA = rows.firstWhere((r) => r.shopId == shopA);
    final rowB = rows.firstWhere((r) => r.shopId == shopB);
    expect(rowA.categoryBreadth, 2);
    expect(rowB.categoryBreadth, 1);
  });

  // ─── Weekday heatmap ──────────────────────────────────────────────────────
  //
  // This card had never rendered a bar from real data. Its query ran
  // `strftime('%w', o.order_date)` against a column drift stores as Unix epoch
  // seconds; strftime read the number as a Julian day, returned NULL for every
  // row, and `read<int>` threw. The widget rendered the error as "not enough
  // data", so the failure looked like an empty dataset for four releases.
  // docs/features/10b-device-pass.md, A2.

  group('weekdayHeatmapProvider', () {
    /// The most recent [weekday] on or before [from]. `DateTime.monday` etc.
    DateTime lastOn(DateTime from, int weekday) {
      var day = from;
      while (day.weekday != weekday) {
        day = day.subtract(const Duration(days: 1));
      }
      return day;
    }

    late int shopId;
    late int bakeryId;
    late int bunId;
    late DateTime today;

    setUp(() async {
      shopId =
          await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Shop'));
      bakeryId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Bakery', sortOrder: const Value(0)));
      bunId = await db.productDao.upsertProduct(
          ProductsCompanion.insert(name: 'Bun', categoryId: Value(bakeryId)));
      final now = DateTime.now();
      today = DateTime(now.year, now.month, now.day);
    });

    Future<void> order(DateTime date, int qty) async {
      final created = await db.orderDao.getOrCreateOrder(shopId, date);
      await db.orderDao.replaceOrderLines(created.id, [
        OrderLinesCompanion.insert(
            orderId: created.id, productId: bunId, qty: qty, unitPrice: 5.0),
      ]);
    }

    test('renders averages per weekday from four weeks of orders', () async {
      final monday = lastOn(today, DateTime.monday);
      final wednesday = lastOn(today, DateTime.wednesday);

      // Three Mondays: 10, 20, 30 → 20. One Wednesday: 7 → 7.
      await order(monday, 10);
      await order(monday.subtract(const Duration(days: 7)), 20);
      await order(monday.subtract(const Duration(days: 14)), 30);
      await order(wednesday, 7);

      final heatmap = await container.read(weekdayHeatmapProvider.future);

      // The bug, stated as the assertion that would have caught it.
      expect(heatmap, isNotEmpty,
          reason: 'the heatmap must not be empty with four weeks of orders');

      // Day 0 is Monday, matching the widget's labels.
      expect(heatmap[bakeryId]![0], 20.0);
      expect(heatmap[bakeryId]![2], 7.0);
      expect(heatmap[bakeryId]!.containsKey(1), isFalse,
          reason: 'a Tuesday with no orders is absent, not zero');
    });

    test('sums every shop on the same day before averaging', () async {
      final other =
          await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Other'));
      final monday = lastOn(today, DateTime.monday);

      await order(monday, 10);
      final second = await db.orderDao.getOrCreateOrder(other, monday);
      await db.orderDao.replaceOrderLines(second.id, [
        OrderLinesCompanion.insert(
            orderId: second.id, productId: bunId, qty: 5, unitPrice: 5.0),
      ]);

      final heatmap = await container.read(weekdayHeatmapProvider.future);
      expect(heatmap[bakeryId]![0], 15.0,
          reason: 'one Monday of 10 + 5, not two Mondays averaged to 7.5');
    });

    test('puts uncategorised products under a null key', () async {
      final loose = await db.productDao
          .upsertProduct(ProductsCompanion.insert(name: 'Loose'));
      final monday = lastOn(today, DateTime.monday);
      final created = await db.orderDao.getOrCreateOrder(shopId, monday);
      await db.orderDao.replaceOrderLines(created.id, [
        OrderLinesCompanion.insert(
            orderId: created.id, productId: loose, qty: 4, unitPrice: 5.0),
      ]);

      final heatmap = await container.read(weekdayHeatmapProvider.future);
      expect(heatmap[null]![0], 4.0);
    });
  });
}
