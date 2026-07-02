import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables/shops.dart';
import 'tables/products.dart';
import 'tables/shop_prices.dart';
import 'tables/standing_orders.dart';
import 'tables/daily_orders.dart';
import 'tables/order_lines.dart';

export 'tables/shops.dart';
export 'tables/products.dart';
export 'tables/shop_prices.dart';
export 'tables/standing_orders.dart';
export 'tables/daily_orders.dart';
export 'tables/order_lines.dart';

part 'app_database.g.dart';
part 'daos/shop_dao.dart';
part 'daos/product_dao.dart';
part 'daos/order_dao.dart';
part 'daos/price_dao.dart';

@DriftDatabase(
  tables: [Shops, Products, ShopPrices, StandingOrders, DailyOrders, OrderLines],
  daos: [ShopDao, ProductDao, OrderDao, PriceDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'milano_orders.db'));
    return NativeDatabase.createInBackground(file);
  });
}
