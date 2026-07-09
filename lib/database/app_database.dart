import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables/shops.dart';
import 'tables/products.dart';
import 'tables/categories.dart';
import 'tables/shop_prices.dart';
import 'tables/standing_orders.dart';
import 'tables/daily_orders.dart';
import 'tables/order_lines.dart';
import 'tables/business_info.dart';
import 'seed_data.dart';

export 'tables/shops.dart';
export 'tables/products.dart';
export 'tables/categories.dart';
export 'tables/shop_prices.dart';
export 'tables/standing_orders.dart';
export 'tables/daily_orders.dart';
export 'tables/order_lines.dart';
export 'tables/business_info.dart';

part 'app_database.g.dart';
part 'daos/shop_dao.dart';
part 'daos/product_dao.dart';
part 'daos/category_dao.dart';
part 'daos/order_dao.dart';
part 'daos/price_dao.dart';
part 'daos/business_info_dao.dart';
part 'daos/backup_dao.dart';

@DriftDatabase(
  tables: [Categories, Shops, Products, ShopPrices, StandingOrders, DailyOrders, OrderLines, BusinessInfo],
  daos: [CategoryDao, ShopDao, ProductDao, OrderDao, PriceDao, BusinessInfoDao, BackupDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(products, products.price);
          }
          if (from < 3) {
            await m.createTable(businessInfo);
          }
          if (from < 4) {
            await m.createTable(categories);
            await m.addColumn(products, products.categoryId);
            await seedDefaultCategories(this);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'milano_orders.db'));
    return NativeDatabase.createInBackground(file);
  });
}
