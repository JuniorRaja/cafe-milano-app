import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'app_database.dart';

Future<void> seedDatabase(AppDatabase db) async {
  final existing = await db.select(db.shops).get();
  if (existing.isNotEmpty) {
    debugPrint('[MilanoOrders] DB already seeded (${existing.length} shops). Skipping.');
    return;
  }
  debugPrint('[MilanoOrders] Seeding database...');

  await db.transaction(() async {
    // 2 shops
    final shopIds = <int>[];
    for (final companion in [
      ShopsCompanion.insert(name: 'Hotel Raj', area: const Value('Anna Nagar, Chennai')),
      ShopsCompanion.insert(name: 'Star Bakery', area: const Value('T Nagar, Chennai')),
    ]) {
      shopIds.add(await db.into(db.shops).insert(companion));
    }

    // 6 products, each with a default price [bun, vegPuff, eggPuff, bread, cakeRusk, sweetBun]
    final defaultPrices = [5.0, 8.0, 9.0, 25.0, 5.0, 7.0];
    final productIds = <int>[];
    for (var i = 0; i < 6; i++) {
      final name = ['Bun', 'Veg Puff', 'Egg Puff', 'Bread', 'Cake Rusk', 'Sweet Bun'][i];
      final unit = i == 3 ? 'loaf' : 'pc';
      productIds.add(await db.into(db.products).insert(ProductsCompanion.insert(
            name: name,
            unit: Value(unit),
            price: Value(defaultPrices[i]),
          )));
    }

    // Shop-specific price overrides.
    // Hotel Raj explicitly sets a shop price for every product (matching the defaults).
    // Star Bakery only overrides Bun and Bread — the other products fall back to the product default price.
    final starOverrides = {0: 4.0, 3: 25.0};

    for (var j = 0; j < productIds.length; j++) {
      await db.into(db.shopPrices).insert(ShopPricesCompanion.insert(
            shopId: shopIds[0],
            productId: productIds[j],
            price: defaultPrices[j],
          ));
    }
    for (final entry in starOverrides.entries) {
      await db.into(db.shopPrices).insert(ShopPricesCompanion.insert(
            shopId: shopIds[1],
            productId: productIds[entry.key],
            price: entry.value,
          ));
    }

    // Standing order quantities per shop × product
    final standing = [
      [30, 15, 10, 5, 20, 10], // Hotel Raj
      [20, 10, 8, 3, 15, 8], // Star Bakery
    ];

    for (var i = 0; i < shopIds.length; i++) {
      for (var j = 0; j < productIds.length; j++) {
        await db.into(db.standingOrders).insert(StandingOrdersCompanion.insert(
          shopId: shopIds[i],
          productId: productIds[j],
          defaultQty: Value(standing[i][j]),
        ));
      }
    }

    // Two test orders for today — one confirmed, one pending
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    // Hotel Raj — confirmed, 3 products
    final rajOrderId = await db.into(db.dailyOrders).insert(
          DailyOrdersCompanion.insert(
            shopId: shopIds[0],
            orderDate: todayStart,
            isConfirmed: const Value(true),
          ),
        );
    for (final line in [
      (productId: productIds[0], qty: 30, price: defaultPrices[0]), // Bun
      (productId: productIds[1], qty: 15, price: defaultPrices[1]), // Veg Puff
      (productId: productIds[2], qty: 10, price: defaultPrices[2]), // Egg Puff
    ]) {
      await db.into(db.orderLines).insert(OrderLinesCompanion.insert(
            orderId: rajOrderId,
            productId: line.productId,
            qty: line.qty,
            unitPrice: line.price,
          ));
    }

    // Star Bakery — pending, 2 products
    final starOrderId = await db.into(db.dailyOrders).insert(
          DailyOrdersCompanion.insert(
            shopId: shopIds[1],
            orderDate: todayStart,
          ),
        );
    for (final line in [
      (productId: productIds[0], qty: 20, price: starOverrides[0]!), // Bun
      (productId: productIds[3], qty: 3, price: starOverrides[3]!),  // Bread
    ]) {
      await db.into(db.orderLines).insert(OrderLinesCompanion.insert(
            orderId: starOrderId,
            productId: line.productId,
            qty: line.qty,
            unitPrice: line.price,
          ));
    }
  });
  debugPrint('[MilanoOrders] Seed complete — 2 shops, 6 products, prices, standing orders, and 2 test orders inserted.');
}
