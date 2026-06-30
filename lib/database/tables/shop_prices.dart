import 'package:drift/drift.dart';
import 'shops.dart';
import 'products.dart';

class ShopPrices extends Table {
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get price => real()();

  @override
  Set<Column> get primaryKey => {shopId, productId};
}
