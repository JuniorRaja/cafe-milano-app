import 'package:cafe_milano/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _freshDb() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  // ─── ShopDao ──────────────────────────────────────────────────────────────

  group('ShopDao', () {
    late AppDatabase db;
    setUp(() => db = _freshDb());
    tearDown(() => db.close());

    test('upsertShop inserts and stream reflects it', () async {
      final id = await db.shopDao.upsertShop(
        ShopsCompanion.insert(name: 'Hotel Raj', area: const Value('Anna Nagar')),
      );
      final shops = await db.shopDao.watchActiveShops().first;
      expect(shops.length, 1);
      expect(shops.first.id, id);
      expect(shops.first.name, 'Hotel Raj');
      expect(shops.first.area, 'Anna Nagar');
    });

    test('upsertShop updates existing shop when id provided', () async {
      final id = await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Old Name'));
      await db.shopDao.upsertShop(ShopsCompanion(id: Value(id), name: const Value('New Name')));
      final shops = await db.shopDao.watchActiveShops().first;
      expect(shops.length, 1);
      expect(shops.first.name, 'New Name');
    });

    test('watchActiveShops excludes inactive shops', () async {
      final id = await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Active'));
      await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Inactive'));
      final all = await db.shopDao.watchAllShops().first;
      final inactiveId = all.firstWhere((s) => s.name == 'Inactive').id;
      await db.shopDao.setShopActive(inactiveId, false);

      final active = await db.shopDao.watchActiveShops().first;
      expect(active.length, 1);
      expect(active.first.id, id);
    });

    test('setShopActive can deactivate and re-activate', () async {
      final id = await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Shop'));
      await db.shopDao.setShopActive(id, false);
      expect(await db.shopDao.watchActiveShops().first, isEmpty);
      await db.shopDao.setShopActive(id, true);
      expect((await db.shopDao.watchActiveShops().first).length, 1);
    });

    test('watchAllShops returns all shops ordered by name', () async {
      await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Zebra'));
      await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Apple'));
      final all = await db.shopDao.watchAllShops().first;
      expect(all.map((s) => s.name), ['Apple', 'Zebra']);
    });
  });

  // ─── ProductDao ───────────────────────────────────────────────────────────

  group('ProductDao', () {
    late AppDatabase db;
    setUp(() => db = _freshDb());
    tearDown(() => db.close());

    test('upsertProduct inserts with unit', () async {
      await db.productDao.upsertProduct(
        ProductsCompanion.insert(name: 'Bun', unit: const Value('pc')),
      );
      final products = await db.productDao.watchActiveProducts().first;
      expect(products.length, 1);
      expect(products.first.name, 'Bun');
      expect(products.first.unit, 'pc');
    });

    test('upsertProduct updates existing product', () async {
      final id = await db.productDao.upsertProduct(ProductsCompanion.insert(name: 'Old'));
      await db.productDao.upsertProduct(
        ProductsCompanion(id: Value(id), name: const Value('New')),
      );
      final products = await db.productDao.watchActiveProducts().first;
      expect(products.first.name, 'New');
    });

    test('watchActiveProducts excludes inactive', () async {
      final id = await db.productDao.upsertProduct(ProductsCompanion.insert(name: 'Puff'));
      await db.productDao.setProductActive(id, false);
      expect(await db.productDao.watchActiveProducts().first, isEmpty);
    });

    test('setProductActive can re-activate', () async {
      final id = await db.productDao.upsertProduct(ProductsCompanion.insert(name: 'Cake'));
      await db.productDao.setProductActive(id, false);
      await db.productDao.setProductActive(id, true);
      expect((await db.productDao.watchActiveProducts().first).length, 1);
    });
  });

  // ─── OrderDao ─────────────────────────────────────────────────────────────

  group('OrderDao', () {
    late AppDatabase db;
    late int shopId;
    late int productId;
    final today = DateTime(2025, 7, 1);

    setUp(() async {
      db = _freshDb();
      shopId = await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Test Shop'));
      productId = await db.productDao.upsertProduct(ProductsCompanion.insert(name: 'Bun'));
    });
    tearDown(() => db.close());

    test('getOrCreateOrder creates a new order', () async {
      final order = await db.orderDao.getOrCreateOrder(shopId, today);
      expect(order.shopId, shopId);
      expect(order.orderDate, today);
      expect(order.isConfirmed, false);
    });

    test('getOrCreateOrder is idempotent — same id on second call', () async {
      final first = await db.orderDao.getOrCreateOrder(shopId, today);
      final second = await db.orderDao.getOrCreateOrder(shopId, today);
      expect(second.id, first.id);
      final orders = await db.orderDao.watchShopOrdersForDate(today).first;
      expect(orders.length, 1);
    });

    test('upsertOrderWithLines skips zero-qty lines', () async {
      final order = await db.orderDao.getOrCreateOrder(shopId, today);
      final p2 = await db.productDao.upsertProduct(ProductsCompanion.insert(name: 'Puff'));

      await db.orderDao.upsertOrderWithLines(order, [
        OrderLinesCompanion(productId: Value(productId), qty: const Value(5), unitPrice: const Value(5.0)),
        OrderLinesCompanion(productId: Value(p2), qty: const Value(0), unitPrice: const Value(8.0)),
      ]);

      final result = await db.orderDao.watchOrderWithLines(order.id).first;
      expect(result!.lines.length, 1);
      expect(result.lines.first.productId, productId);
    });

    test('upsertOrderWithLines replaces previous lines on re-save', () async {
      final order = await db.orderDao.getOrCreateOrder(shopId, today);

      await db.orderDao.upsertOrderWithLines(order, [
        OrderLinesCompanion(productId: Value(productId), qty: const Value(10), unitPrice: const Value(5.0)),
      ]);
      await db.orderDao.upsertOrderWithLines(order, [
        OrderLinesCompanion(productId: Value(productId), qty: const Value(25), unitPrice: const Value(5.0)),
      ]);

      final result = await db.orderDao.watchOrderWithLines(order.id).first;
      expect(result!.lines.length, 1);
      expect(result.lines.first.qty, 25);
    });

    test('upsertOrderWithLines with all zero qty leaves no lines', () async {
      final order = await db.orderDao.getOrCreateOrder(shopId, today);

      await db.orderDao.upsertOrderWithLines(order, [
        OrderLinesCompanion(productId: Value(productId), qty: const Value(0), unitPrice: const Value(5.0)),
      ]);

      final result = await db.orderDao.watchOrderWithLines(order.id).first;
      expect(result!.lines, isEmpty);
    });

    test('setConfirmed flips isConfirmed', () async {
      final order = await db.orderDao.getOrCreateOrder(shopId, today);
      await db.orderDao.setConfirmed(order.id, true);
      final result = await db.orderDao.watchOrderWithLines(order.id).first;
      expect(result!.order.isConfirmed, true);
      await db.orderDao.setConfirmed(order.id, false);
      final result2 = await db.orderDao.watchOrderWithLines(order.id).first;
      expect(result2!.order.isConfirmed, false);
    });

    test('watchShopOrdersForDate filters by date', () async {
      final yesterday = DateTime(2025, 6, 30);
      await db.orderDao.getOrCreateOrder(shopId, today);
      await db.orderDao.getOrCreateOrder(shopId, yesterday);

      final todayOrders = await db.orderDao.watchShopOrdersForDate(today).first;
      expect(todayOrders.length, 1);
      expect(todayOrders.first.orderDate, today);
    });

    test('watchOrderWithLines returns null for non-existent order', () async {
      final result = await db.orderDao.watchOrderWithLines(999).first;
      expect(result, isNull);
    });

    test('watchOrderWithLines returns empty lines when order has no lines', () async {
      final order = await db.orderDao.getOrCreateOrder(shopId, today);
      final result = await db.orderDao.watchOrderWithLines(order.id).first;
      expect(result, isNotNull);
      expect(result!.lines, isEmpty);
    });

    test('unitPrice snapshot is stored and retrieved correctly', () async {
      final order = await db.orderDao.getOrCreateOrder(shopId, today);
      await db.orderDao.upsertOrderWithLines(order, [
        OrderLinesCompanion(productId: Value(productId), qty: const Value(10), unitPrice: const Value(7.5)),
      ]);
      final result = await db.orderDao.watchOrderWithLines(order.id).first;
      expect(result!.lines.first.unitPrice, 7.5);
    });
  });

  // ─── PriceDao ─────────────────────────────────────────────────────────────

  group('PriceDao', () {
    late AppDatabase db;
    late int shopId;
    late int productId;

    setUp(() async {
      db = _freshDb();
      shopId = await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Shop'));
      productId = await db.productDao.upsertProduct(ProductsCompanion.insert(name: 'Bun'));
    });
    tearDown(() => db.close());

    test('getPrice returns null when not set', () async {
      expect(await db.priceDao.getPrice(shopId, productId), isNull);
    });

    test('upsertPrice inserts and getPrice retrieves it', () async {
      await db.priceDao.upsertPrice(
        ShopPricesCompanion.insert(shopId: shopId, productId: productId, price: 5.0),
      );
      final price = await db.priceDao.getPrice(shopId, productId);
      expect(price!.price, 5.0);
    });

    test('upsertPrice updates existing price on conflict', () async {
      await db.priceDao.upsertPrice(
        ShopPricesCompanion.insert(shopId: shopId, productId: productId, price: 5.0),
      );
      await db.priceDao.upsertPrice(
        ShopPricesCompanion.insert(shopId: shopId, productId: productId, price: 7.0),
      );
      final price = await db.priceDao.getPrice(shopId, productId);
      expect(price!.price, 7.0);
    });

    test('watchPricesForShop scopes to the given shop only', () async {
      final otherShop = await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Other'));
      await db.priceDao.upsertPrice(
        ShopPricesCompanion.insert(shopId: shopId, productId: productId, price: 5.0),
      );
      await db.priceDao.upsertPrice(
        ShopPricesCompanion.insert(shopId: otherShop, productId: productId, price: 9.0),
      );
      final prices = await db.priceDao.watchPricesForShop(shopId).first;
      expect(prices.length, 1);
      expect(prices.first.price, 5.0);
    });

    test('upsertStandingOrder inserts defaultQty', () async {
      await db.priceDao.upsertStandingOrder(
        StandingOrdersCompanion.insert(shopId: shopId, productId: productId, defaultQty: const Value(30)),
      );
      final orders = await db.priceDao.watchStandingOrdersForShop(shopId).first;
      expect(orders.length, 1);
      expect(orders.first.defaultQty, 30);
    });

    test('upsertStandingOrder updates existing qty on conflict', () async {
      await db.priceDao.upsertStandingOrder(
        StandingOrdersCompanion.insert(shopId: shopId, productId: productId, defaultQty: const Value(30)),
      );
      await db.priceDao.upsertStandingOrder(
        StandingOrdersCompanion.insert(shopId: shopId, productId: productId, defaultQty: const Value(50)),
      );
      final orders = await db.priceDao.watchStandingOrdersForShop(shopId).first;
      expect(orders.first.defaultQty, 50);
    });

    test('watchStandingOrdersForShop scopes to given shop', () async {
      final otherShop = await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Other'));
      await db.priceDao.upsertStandingOrder(
        StandingOrdersCompanion.insert(shopId: shopId, productId: productId, defaultQty: const Value(20)),
      );
      await db.priceDao.upsertStandingOrder(
        StandingOrdersCompanion.insert(shopId: otherShop, productId: productId, defaultQty: const Value(99)),
      );
      final orders = await db.priceDao.watchStandingOrdersForShop(shopId).first;
      expect(orders.length, 1);
      expect(orders.first.defaultQty, 20);
    });
  });
}
