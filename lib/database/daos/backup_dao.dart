part of '../app_database.dart';

@DriftAccessor(tables: [
  Categories,
  Shops,
  Products,
  ShopPrices,
  StandingOrders,
  DailyOrders,
  OrderLines,
  BusinessInfo,
  Payments,
  PaymentAllocations,
])
class BackupDao extends DatabaseAccessor<AppDatabase> with _$BackupDaoMixin {
  BackupDao(super.db);

  Future<Map<String, dynamic>> exportAll() async {
    final categoriesList = await select(categories).get();
    final shopsList = await select(shops).get();
    final productsList = await select(products).get();
    final shopPricesList = await select(shopPrices).get();
    final standingOrdersList = await select(standingOrders).get();
    final dailyOrdersList = await select(dailyOrders).get();
    final orderLinesList = await select(orderLines).get();
    final businessInfoRow = await select(businessInfo).getSingleOrNull();
    final paymentsList = await select(payments).get();
    final paymentAllocationsList = await select(paymentAllocations).get();

    return {
      'categories': categoriesList.map((e) => e.toJson()).toList(),
      'shops': shopsList.map((e) => e.toJson()).toList(),
      'products': productsList.map((e) => e.toJson()).toList(),
      'shopPrices': shopPricesList.map((e) => e.toJson()).toList(),
      'standingOrders': standingOrdersList.map((e) => e.toJson()).toList(),
      'dailyOrders': dailyOrdersList.map((e) => e.toJson()).toList(),
      'orderLines': orderLinesList.map((e) => e.toJson()).toList(),
      'businessInfo': businessInfoRow?.toJson(),
      'payments': paymentsList.map((e) => e.toJson()).toList(),
      'paymentAllocations': paymentAllocationsList.map((e) => e.toJson()).toList(),
    };
  }

  Future<void> restoreAll(Map<String, dynamic> data) async {
    await transaction(() async {
      // Delete in FK-safe order (dependents first). paymentAllocations
      // references both payments and dailyOrders, so it must go before either.
      await delete(orderLines).go();
      await delete(paymentAllocations).go();
      await delete(payments).go();
      await delete(dailyOrders).go();
      await delete(standingOrders).go();
      await delete(shopPrices).go();
      await delete(products).go();   // products FK → categories
      await delete(categories).go();
      await delete(shops).go();
      await delete(businessInfo).go();

      // Insert in FK-safe order (dependencies first)
      for (final json in (data['categories'] as List? ?? [])) {
        await into(categories).insert(
          Category.fromJson(json as Map<String, dynamic>),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final json in data['shops'] as List) {
        await into(shops).insert(
          Shop.fromJson(json as Map<String, dynamic>),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final json in (data['payments'] as List? ?? [])) {
        await into(payments).insert(
          Payment.fromJson(json as Map<String, dynamic>),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final json in data['products'] as List) {
        await into(products).insert(
          Product.fromJson(json as Map<String, dynamic>),
          mode: InsertMode.insertOrReplace,
        );
      }
      final businessInfoJson = data['businessInfo'];
      if (businessInfoJson != null) {
        await into(businessInfo).insert(
          BusinessInfoData.fromJson(businessInfoJson as Map<String, dynamic>),
          mode: InsertMode.insertOrReplace,
        );
      }
      // Backups from pre-FK builds (schema < 5) can carry shop_prices /
      // standing_orders rows that point at a since-deleted shop or product.
      // An in-place v4->v5 upgrade scrubs these in _cleanOrphans(); a restore
      // bypasses migrations, so drop them here the same way or the insert
      // trips FOREIGN KEY constraint (SqliteException 787).
      final shopIds = {
        for (final j in (data['shops'] as List? ?? []))
          (j as Map)['id'] as int,
      };
      final productIds = {
        for (final j in (data['products'] as List? ?? []))
          (j as Map)['id'] as int,
      };
      for (final json in data['shopPrices'] as List) {
        final m = json as Map<String, dynamic>;
        if (!shopIds.contains(m['shopId']) ||
            !productIds.contains(m['productId'])) {
          continue;
        }
        await into(shopPrices).insert(
          ShopPrice.fromJson(m),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final json in data['standingOrders'] as List) {
        final m = json as Map<String, dynamic>;
        if (!shopIds.contains(m['shopId']) ||
            !productIds.contains(m['productId'])) {
          continue;
        }
        await into(standingOrders).insert(
          StandingOrder.fromJson(m),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final json in data['dailyOrders'] as List) {
        await into(dailyOrders).insert(
          DailyOrder.fromJson(json as Map<String, dynamic>),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final json in data['orderLines'] as List) {
        await into(orderLines).insert(
          OrderLine.fromJson(json as Map<String, dynamic>),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final json in (data['paymentAllocations'] as List? ?? [])) {
        await into(paymentAllocations).insert(
          PaymentAllocation.fromJson(json as Map<String, dynamic>),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }
}
