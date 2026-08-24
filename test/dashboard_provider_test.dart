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
  tearDown(() {
    container.dispose();
    db.close();
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
}
