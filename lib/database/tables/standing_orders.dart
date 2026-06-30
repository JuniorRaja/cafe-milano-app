import 'package:drift/drift.dart';
import 'shops.dart';
import 'products.dart';

class StandingOrders extends Table {
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get defaultQty => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {shopId, productId};
}
