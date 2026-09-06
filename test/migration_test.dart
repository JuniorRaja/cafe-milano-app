import 'dart:io';
import 'package:milano_orders/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v4 -> v6 upgrade cleans a real orphan, enables FK, adds ledger', () async {
    final dir = await Directory.systemTemp.createTemp('milano_migration_test');
    final file = File('${dir.path}/test.db');

    // Build a v4-shaped database. `createAll` builds the *current* schema, so
    // everything v5 and v6 added has to be stripped back off before the file is
    // stamped as v4 — otherwise onUpgrade re-adds it and fails on a duplicate.
    // Keep this teardown in step with the migration chain in app_database.dart.
    final setupDb = AppDatabase.forTesting(NativeDatabase(file));
    await setupDb.customStatement('PRAGMA foreign_keys = OFF');
    final shopId =
        await setupDb.into(setupDb.shops).insert(ShopsCompanion.insert(name: 'Ghost Shop'));
    final productId =
        await setupDb.into(setupDb.products).insert(ProductsCompanion.insert(name: 'Bun'));
    await setupDb.into(setupDb.shopPrices).insert(
        ShopPricesCompanion.insert(shopId: shopId, productId: productId, price: 5.0));
    await setupDb.customStatement('DELETE FROM shops WHERE id = $shopId');
    await setupDb.customStatement('DROP INDEX IF EXISTS idx_daily_orders_date');
    await setupDb.customStatement('DROP INDEX IF EXISTS idx_daily_orders_shop');
    await setupDb.customStatement('DROP INDEX IF EXISTS idx_order_lines_order');
    await setupDb.customStatement('DROP INDEX IF EXISTS idx_order_lines_product');

    // Undo v6: the ledger tables and the two shops columns.
    await setupDb.customStatement('DROP TABLE IF EXISTS payment_allocations');
    await setupDb.customStatement('DROP TABLE IF EXISTS payments');
    await setupDb.customStatement('ALTER TABLE shops DROP COLUMN opening_balance');
    await setupDb.customStatement('ALTER TABLE shops DROP COLUMN opening_balance_at');

    await setupDb.customStatement('PRAGMA user_version = 4');
    await setupDb.close();

    // Reopen normally — triggers onUpgrade(from: 4, to: 5).
    final upgraded = AppDatabase.forTesting(NativeDatabase(file));

    final fkStatus = await upgraded.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fkStatus.data['foreign_keys'], 1);

    final violations = await upgraded.customSelect('PRAGMA foreign_key_check').get();
    expect(violations, isEmpty);

    final remainingPrices = await upgraded.select(upgraded.shopPrices).get();
    expect(remainingPrices, isEmpty);

    final indexes = await upgraded
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'")
        .get();
    expect(
      indexes.map((r) => r.data['name']),
      containsAll([
        'idx_daily_orders_date',
        'idx_daily_orders_shop',
        'idx_order_lines_order',
        'idx_order_lines_product',
      ]),
    );

    // v6 arrived: the ledger tables exist and shops carries its opening balance.
    final tables = await upgraded
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    expect(tables.map((r) => r.data['name']),
        containsAll(['payments', 'payment_allocations']));

    final shopCols = await upgraded.customSelect('PRAGMA table_info(shops)').get();
    expect(shopCols.map((r) => r.data['name']),
        containsAll(['opening_balance', 'opening_balance_at']));

    await upgraded.close();
    await dir.delete(recursive: true);
  });
}
