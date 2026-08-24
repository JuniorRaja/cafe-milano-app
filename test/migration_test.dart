import 'dart:io';
import 'package:milano_orders/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v4 -> v5 upgrade cleans a real orphan and enables FK + indexes', () async {
    final dir = await Directory.systemTemp.createTemp('milano_migration_test');
    final file = File('${dir.path}/test.db');

    // Build a v4-shaped database: same tables as v5 (the v4->v5 migration only
    // adds indexes), but with FK enforcement off and a real orphan row —
    // exactly what a pre-fix install looks like after a shop was deleted while
    // it still had a shop_price.
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

    await upgraded.close();
    await dir.delete(recursive: true);
  });
}
