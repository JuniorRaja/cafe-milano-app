import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

final pricesForShopProvider =
    StreamProvider.autoDispose.family<List<ShopPrice>, int>((ref, shopId) {
  return ref.watch(databaseProvider).priceDao.watchPricesForShop(shopId);
});

final standingOrdersForShopProvider =
    StreamProvider.autoDispose.family<List<StandingOrder>, int>((ref, shopId) {
  return ref.watch(databaseProvider).priceDao.watchStandingOrdersForShop(shopId);
});

/// Price and standing-order coverage for the Settings tiles. One aggregate,
/// not a per-shop read — see [PriceDao.watchCatalogueCoverage].
final catalogueCoverageProvider =
    StreamProvider.autoDispose<CatalogueCoverage>((ref) {
  return ref.watch(databaseProvider).priceDao.watchCatalogueCoverage();
});
