part of '../app_database.dart';

@DriftAccessor(tables: [Products])
class ProductDao extends DatabaseAccessor<AppDatabase> with _$ProductDaoMixin {
  ProductDao(super.db);

  Stream<List<Product>> watchActiveProducts() => (select(products)
        ..where((p) => p.isActive.equals(true))
        ..orderBy([(p) => OrderingTerm(expression: p.name)]))
      .watch();

  Future<int> upsertProduct(ProductsCompanion companion) =>
      into(products).insertOnConflictUpdate(companion);

  Future<void> setProductActive(int id, bool active) =>
      (update(products)..where((p) => p.id.equals(id)))
          .write(ProductsCompanion(isActive: Value(active)));
}
