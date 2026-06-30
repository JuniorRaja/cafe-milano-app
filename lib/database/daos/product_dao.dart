part of '../app_database.dart';

@DriftAccessor(tables: [Products])
class ProductDao extends DatabaseAccessor<AppDatabase> with _$ProductDaoMixin {
  ProductDao(super.db);

  Stream<List<Product>> watchActiveProducts() => (select(products)
        ..where((p) => p.isActive.equals(true))
        ..orderBy([(p) => OrderingTerm(expression: p.name)]))
      .watch();

  Stream<List<Product>> watchAllProducts() =>
      (select(products)..orderBy([(p) => OrderingTerm(expression: p.name)])).watch();

  Future<Product?> getProduct(int id) =>
      (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<int> upsertProduct(ProductsCompanion companion) =>
      into(products).insertOnConflictUpdate(companion);

  Future<void> setProductActive(int id, bool active) =>
      (update(products)..where((p) => p.id.equals(id)))
          .write(ProductsCompanion(isActive: Value(active)));

  Future<bool> productHasOrderLines(int id) async {
    final rows = await (db.select(db.orderLines)
          ..where((l) => l.productId.equals(id))
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  Future<void> deleteProduct(int id) =>
      (delete(products)..where((p) => p.id.equals(id))).go();
}
