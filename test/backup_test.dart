import 'dart:convert';
import 'package:milano_orders/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _freshDb() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  group('BackupDao', () {
    test('exportAll then restoreAll round-trips all tables through JSON', () async {
      final source = _freshDb();

      final shopId = await source.shopDao.upsertShop(
        ShopsCompanion.insert(name: 'Hotel Raj', area: const Value('Anna Nagar')),
      );
      final productId = await source.productDao.upsertProduct(
        ProductsCompanion.insert(name: 'Bun', unit: const Value('pc'), price: const Value(15.0)),
      );
      await source.priceDao.upsertPrice(
        ShopPricesCompanion.insert(shopId: shopId, productId: productId, price: 12.0),
      );
      await source.priceDao.upsertStandingOrder(
        StandingOrdersCompanion.insert(shopId: shopId, productId: productId, defaultQty: const Value(5)),
      );
      final order = await source.orderDao.getOrCreateOrder(shopId, DateTime(2026, 7, 5));
      await source.orderDao.replaceOrderLines(order.id, [
        OrderLinesCompanion.insert(orderId: order.id, productId: productId, qty: 3, unitPrice: 12.0),
      ]);
      await source.businessInfoDao.upsertBusinessInfo(
        const BusinessInfoCompanion(name: Value('Cafe Milano')),
      );

      final exported = await source.backupDao.exportAll();
      // Simulate the real round trip: write to JSON text and parse it back,
      // exactly like the exported file does.
      final roundTripped = jsonDecode(jsonEncode(exported)) as Map<String, dynamic>;
      await source.close();

      final target = _freshDb();
      await target.backupDao.restoreAll(roundTripped);

      final shops = await target.shopDao.watchAllShops().first;
      expect(shops, hasLength(1));
      expect(shops.first.name, 'Hotel Raj');
      expect(shops.first.area, 'Anna Nagar');

      final products = await target.productDao.watchActiveProducts().first;
      expect(products, hasLength(1));
      expect(products.first.name, 'Bun');
      expect(products.first.price, 15.0);

      final price = await target.priceDao.getPrice(shopId, productId);
      expect(price?.price, 12.0);

      final standingOrders = await target.priceDao.watchStandingOrdersForShop(shopId).first;
      expect(standingOrders, hasLength(1));
      expect(standingOrders.first.defaultQty, 5);

      final restoredOrder = await target.orderDao.watchOrderWithLines(order.id).first;
      expect(restoredOrder, isNotNull);
      expect(restoredOrder!.lines, hasLength(1));
      expect(restoredOrder.lines.first.qty, 3);

      final info = await target.businessInfoDao.watchBusinessInfo().first;
      expect(info?.name, 'Cafe Milano');

      await target.close();
    });

    test('restoreAll replaces existing data rather than merging', () async {
      final db = _freshDb();
      await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Old Shop'));

      final backup = {
        'shops': [
          {'id': 1, 'name': 'New Shop', 'area': null, 'phone': null, 'isActive': true},
        ],
        'products': [],
        'shopPrices': [],
        'standingOrders': [],
        'dailyOrders': [],
        'orderLines': [],
        'businessInfo': null,
      };
      await db.backupDao.restoreAll(backup);

      final shops = await db.shopDao.watchAllShops().first;
      expect(shops, hasLength(1));
      expect(shops.first.name, 'New Shop');

      await db.close();
    });
  });
}
