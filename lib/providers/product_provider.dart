import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'category_provider.dart';
import 'combine.dart';
import 'database_provider.dart';
import 'shop_provider.dart';

final activeProductsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(databaseProvider).productDao.watchActiveProducts();
});

final allProductsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(databaseProvider).productDao.watchAllProducts();
});

/// The active shops and the active products, as one `AsyncValue`.
///
/// The Price Matrix and Standing Orders both need exactly this pair and both
/// used to nest `productsAsync.when` inside `shopsAsync.when` — two loading
/// spinners, two error branches and four states to reason about for one
/// screen. One `.when` each instead.
typedef ShopsAndProducts = ({List<Shop> shops, List<Product> products});

final activeShopsAndProductsProvider =
    Provider.autoDispose<AsyncValue<ShopsAndProducts>>((ref) {
      final shops = ref.watch(activeShopsProvider);
      final products = ref.watch(activeProductsProvider);

      return combineAsync([
        shops,
        products,
      ], () => (shops: shops.requireValue, products: products.requireValue));
    });

/// Every product and every category — active and inactive — as one
/// `AsyncValue`.
///
/// The Products and Categories master lists each need both: Products groups by
/// category, Categories counts products per category. Both used to read the
/// second through `maybeWhen(orElse: () => [])`, so a failed query showed
/// "Puffs · 0 products" rather than saying the count was unavailable.
typedef CatalogueView = ({List<Product> products, List<Category> categories});

final catalogueViewProvider = Provider.autoDispose<AsyncValue<CatalogueView>>((
  ref,
) {
  final products = ref.watch(allProductsProvider);
  final categories = ref.watch(allCategoriesProvider);

  return combineAsync(
    [products, categories],
    () =>
        (products: products.requireValue, categories: categories.requireValue),
  );
});
