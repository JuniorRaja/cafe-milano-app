part of '../app_database.dart';

/// How much of the catalogue is actually configured, for the Settings tiles
/// that report state instead of static prose.
///
/// [priceSlots] is active shops x active products — the number of prices that
/// *could* be set. It is not a target: most shops take the product's default
/// price and never need an override. The figure is there so "212 of 504" reads
/// as coverage rather than as 292 missing rows.
class CatalogueCoverage {
  final int pricesSet;
  final int priceSlots;
  final int shopsWithStandingOrders;

  const CatalogueCoverage({
    required this.pricesSet,
    required this.priceSlots,
    required this.shopsWithStandingOrders,
  });

  static const empty =
      CatalogueCoverage(pricesSet: 0, priceSlots: 0, shopsWithStandingOrders: 0);
}

@DriftAccessor(tables: [ShopPrices, StandingOrders, Shops, Products])
class PriceDao extends DatabaseAccessor<AppDatabase> with _$PriceDaoMixin {
  PriceDao(super.db);

  /// Every Settings coverage figure in one query.
  ///
  /// Read-only and additive, and it is one aggregate rather than a per-shop
  /// read: doing this through [watchPricesForShop] would be an N+1 across 18
  /// shops on a screen that only wants a subtitle, which is exactly what doc
  /// 04 took out of the dashboard.
  Stream<CatalogueCoverage> watchCatalogueCoverage() {
    final query = customSelect(
      'SELECT '
      '(SELECT COUNT(*) FROM shop_prices) AS prices_set, '
      '(SELECT COUNT(*) FROM shops WHERE is_active = 1) AS active_shops, '
      '(SELECT COUNT(*) FROM products WHERE is_active = 1) AS active_products, '
      '(SELECT COUNT(DISTINCT shop_id) FROM standing_orders WHERE default_qty > 0) '
      '  AS standing_shops',
      readsFrom: {shopPrices, standingOrders, shops, products},
    );

    return query.watchSingle().map((row) => CatalogueCoverage(
          pricesSet: row.read<int>('prices_set'),
          priceSlots:
              row.read<int>('active_shops') * row.read<int>('active_products'),
          shopsWithStandingOrders: row.read<int>('standing_shops'),
        ));
  }

  Stream<List<ShopPrice>> watchPricesForShop(int shopId) =>
      (select(shopPrices)..where((p) => p.shopId.equals(shopId))).watch();

  Future<void> upsertPrice(ShopPricesCompanion companion) =>
      into(shopPrices).insertOnConflictUpdate(companion);

  Future<void> deletePrice(int shopId, int productId) =>
      (delete(shopPrices)
            ..where(
              (p) => p.shopId.equals(shopId) & p.productId.equals(productId),
            ))
          .go();

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
