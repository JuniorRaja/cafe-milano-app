part of '../app_database.dart';

@DriftAccessor(tables: [ShopPrices, StandingOrders])
class PriceDao extends DatabaseAccessor<AppDatabase> with _$PriceDaoMixin {
  PriceDao(super.db);

  Stream<List<ShopPrice>> watchPricesForShop(int shopId) =>
      (select(shopPrices)..where((p) => p.shopId.equals(shopId))).watch();

  Future<void> upsertPrice(ShopPricesCompanion companion) =>
      into(shopPrices).insertOnConflictUpdate(companion);

  Future<ShopPrice?> getPrice(int shopId, int productId) =>
      (select(shopPrices)
            ..where(
              (p) => p.shopId.equals(shopId) & p.productId.equals(productId),
            ))
          .getSingleOrNull();

  Stream<List<StandingOrder>> watchStandingOrdersForShop(int shopId) =>
      (select(standingOrders)..where((s) => s.shopId.equals(shopId))).watch();

  Future<void> upsertStandingOrder(StandingOrdersCompanion companion) =>
      into(standingOrders).insertOnConflictUpdate(companion);
}
