part of '../app_database.dart';

@DriftAccessor(tables: [Categories, Products])
class CategoryDao extends DatabaseAccessor<AppDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Stream<List<Category>> watchActive() =>
      (select(categories)
        ..where((c) => c.isActive.equals(true))
        ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
      .watch();

  Stream<List<Category>> watchAll() =>
      (select(categories)
        ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
      .watch();

  Future<int> insertCategory(String name, int sortOrder) =>
      into(categories).insert(CategoriesCompanion.insert(
        name: name,
        sortOrder: Value(sortOrder),
      ));

  Future<void> renameCategory(int id, String name) =>
      (update(categories)..where((c) => c.id.equals(id)))
          .write(CategoriesCompanion(name: Value(name)));

  Future<void> reorderCategory(int id, int sortOrder) =>
      (update(categories)..where((c) => c.id.equals(id)))
          .write(CategoriesCompanion(sortOrder: Value(sortOrder)));

  Future<void> setActive(int id, bool active) =>
      (update(categories)..where((c) => c.id.equals(id)))
          .write(CategoriesCompanion(isActive: Value(active)));

  Future<int> countProductsForCategory(int id) async {
    final count = countAll();
    final query = selectOnly(products)
      ..addColumns([count])
      ..where(products.categoryId.equals(id));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> deleteCategory(int id) async {
    await (update(products)..where((p) => p.categoryId.equals(id)))
        .write(ProductsCompanion(categoryId: Value<int?>(null)));
    await (delete(categories)..where((c) => c.id.equals(id))).go();
  }
}
