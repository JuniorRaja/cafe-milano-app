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

    return {
      'categories': categoriesList.map((e) => e.toJson()).toList(),
      'shops': shopsList.map((e) => e.toJson()).toList(),
      'products': productsList.map((e) => e.toJson()).toList(),
      'shopPrices': shopPricesList.map((e) => e.toJson()).toList(),
      'standingOrders': standingOrdersList.map((e) => e.toJson()).toList(),
      'dailyOrders': dailyOrdersList.map((e) => e.toJson()).toList(),
      'orderLines': orderLinesList.map((e) => e.toJson()).toList(),
      'businessInfo': businessInfoRow?.toJson(),
    };
  }

  Future<void> restoreAll(Map<String, dynamic> data) async {
    await transaction(() async {
      // Delete in FK-safe order (dependents first)
      await delete(orderLines).go();
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
      for (final json in data['shopPrices'] as List) {
        await into(shopPrices).insert(
          ShopPrice.fromJson(json as Map<String, dynamic>),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final json in data['standingOrders'] as List) {
        await into(standingOrders).insert(
          StandingOrder.fromJson(json as Map<String, dynamic>),
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
    });
  }
}
