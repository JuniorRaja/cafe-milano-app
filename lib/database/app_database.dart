import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
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
part 'daos/dashboard_dao.dart';

@DriftDatabase(
  tables: [Categories, Shops, Products, ShopPrices, StandingOrders, DailyOrders, OrderLines, BusinessInfo],
  daos: [CategoryDao, ShopDao, ProductDao, OrderDao, PriceDao, BusinessInfoDao, BackupDao, DashboardDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
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
          if (from < 5) {
            await _cleanOrphans();
            await _createIndexes();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // Deletes never had FK enforcement behind them, so shop_prices / standing_orders
  // rows whose shop or product was deleted are the only realistic orphans (order_lines
  // and daily_orders were already blocked by UI guards). Must run before the
  // foreign_keys pragma is turned on, or a real orphan would fail the app open.
  Future<void> _cleanOrphans() async {
    final shopPricesRemoved = await customUpdate(
      'DELETE FROM shop_prices WHERE shop_id NOT IN (SELECT id FROM shops) '
      'OR product_id NOT IN (SELECT id FROM products)',
      updates: {shopPrices},
    );
    final standingOrdersRemoved = await customUpdate(
      'DELETE FROM standing_orders WHERE shop_id NOT IN (SELECT id FROM shops) '
      'OR product_id NOT IN (SELECT id FROM products)',
      updates: {standingOrders},
    );
    final orderLinesRemoved = await customUpdate(
      'DELETE FROM order_lines WHERE order_id NOT IN (SELECT id FROM daily_orders) '
      'OR product_id NOT IN (SELECT id FROM products)',
      updates: {orderLines},
    );
    debugPrint(
      '[MilanoOrders] v4->v5 orphan cleanup: $shopPricesRemoved shop_prices, '
      '$standingOrdersRemoved standing_orders, $orderLinesRemoved order_lines rows removed.',
    );
  }

  // Single-column indexes, not a (order_date, shop_id) composite: most dashboard
  // queries filter by order_date alone, and the shop_id index also needs to serve
  // pure per-shop lookups (05-ledger-foundation) that don't filter by date.
  Future<void> _createIndexes() async {
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_daily_orders_date ON daily_orders(order_date)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_daily_orders_shop ON daily_orders(shop_id)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_order_lines_order ON order_lines(order_id)');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_order_lines_product ON order_lines(product_id)');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'milano_orders.db'));
    return NativeDatabase.createInBackground(file);
  });
}
