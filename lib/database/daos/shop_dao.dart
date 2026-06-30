part of '../app_database.dart';

@DriftAccessor(tables: [Shops])
class ShopDao extends DatabaseAccessor<AppDatabase> with _$ShopDaoMixin {
  ShopDao(super.db);

  Stream<List<Shop>> watchActiveShops() => (select(shops)
        ..where((s) => s.isActive.equals(true))
        ..orderBy([(s) => OrderingTerm(expression: s.name)]))
      .watch();

  Stream<List<Shop>> watchAllShops() =>
      (select(shops)..orderBy([(s) => OrderingTerm(expression: s.name)])).watch();

  Future<Shop?> getShop(int id) =>
      (select(shops)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> upsertShop(ShopsCompanion companion) =>
      into(shops).insertOnConflictUpdate(companion);

  Future<void> setShopActive(int id, bool active) =>
      (update(shops)..where((s) => s.id.equals(id)))
          .write(ShopsCompanion(isActive: Value(active)));

  Future<bool> shopHasOrders(int id) async {
    final rows = await (db.select(db.dailyOrders)
          ..where((o) => o.shopId.equals(id))
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  Future<void> deleteShop(int id) =>
      (delete(shops)..where((s) => s.id.equals(id))).go();
}
