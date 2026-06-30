import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'app_database.dart';

Future<void> seedDatabase(AppDatabase db) async {
  final existing = await db.select(db.shops).get();
  if (existing.isNotEmpty) {
    debugPrint('[BakeOrder] DB already seeded (${existing.length} shops). Skipping.');
    return;
  }
  debugPrint('[BakeOrder] Seeding database...');

  await db.transaction(() async {
    // 5 shops
    final shopIds = <int>[];
    for (final companion in [
      ShopsCompanion.insert(name: 'Hotel Raj', area: const Value('Anna Nagar, Chennai')),
      ShopsCompanion.insert(name: 'Star Bakery', area: const Value('T Nagar, Chennai')),
      ShopsCompanion.insert(name: 'New Moon Hotel', area: const Value('Adyar, Chennai')),
      ShopsCompanion.insert(name: 'Sri Murugan Bakery', area: const Value('Velachery, Chennai')),
      ShopsCompanion.insert(name: 'Annapoorna Stores', area: const Value('Mylapore, Chennai')),
    ]) {
      shopIds.add(await db.into(db.shops).insert(companion));
    }

    // 6 products
    final productIds = <int>[];
    for (final companion in [
      ProductsCompanion.insert(name: 'Bun', unit: const Value('pc')),
      ProductsCompanion.insert(name: 'Veg Puff', unit: const Value('pc')),
      ProductsCompanion.insert(name: 'Egg Puff', unit: const Value('pc')),
      ProductsCompanion.insert(name: 'Bread', unit: const Value('loaf')),
      ProductsCompanion.insert(name: 'Cake Rusk', unit: const Value('pc')),
      ProductsCompanion.insert(name: 'Sweet Bun', unit: const Value('pc')),
    ]) {
      productIds.add(await db.into(db.products).insert(companion));
    }

    // Prices per shop × product [bun, vegPuff, eggPuff, bread, cakeRusk, sweetBun]
    final prices = [
      [5.0, 8.0, 9.0, 25.0, 5.0, 7.0], // Hotel Raj
      [4.0, 7.0, 8.0, 25.0, 5.0, 6.0], // Star Bakery
      [5.0, 8.0, 9.0, 26.0, 5.0, 7.0], // New Moon Hotel
      [6.0, 9.0, 10.0, 25.0, 6.0, 8.0], // Sri Murugan Bakery
      [5.0, 8.0, 9.0, 24.0, 5.0, 7.0], // Annapoorna Stores
    ];

    // Standing order quantities per shop × product
    final standing = [
      [30, 15, 10, 5, 20, 10], // Hotel Raj
      [20, 10, 8, 3, 15, 8], // Star Bakery
      [25, 12, 10, 4, 18, 8], // New Moon Hotel
      [40, 20, 15, 6, 25, 12], // Sri Murugan Bakery
      [35, 18, 12, 5, 22, 10], // Annapoorna Stores
    ];

    for (var i = 0; i < shopIds.length; i++) {
      for (var j = 0; j < productIds.length; j++) {
        await db.into(db.shopPrices).insert(ShopPricesCompanion.insert(
          shopId: shopIds[i],
          productId: productIds[j],
          price: prices[i][j],
        ));
        await db.into(db.standingOrders).insert(StandingOrdersCompanion.insert(
          shopId: shopIds[i],
          productId: productIds[j],
          defaultQty: Value(standing[i][j]),
        ));
      }
    }
  });
  debugPrint('[BakeOrder] Seed complete — 5 shops, 6 products, prices and standing orders inserted.');
}
