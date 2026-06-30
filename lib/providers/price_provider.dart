import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

final pricesForShopProvider =
    StreamProvider.family<List<ShopPrice>, int>((ref, shopId) {
  return ref.watch(databaseProvider).priceDao.watchPricesForShop(shopId);
});

final standingOrdersForShopProvider =
    StreamProvider.family<List<StandingOrder>, int>((ref, shopId) {
  return ref.watch(databaseProvider).priceDao.watchStandingOrdersForShop(shopId);
});
