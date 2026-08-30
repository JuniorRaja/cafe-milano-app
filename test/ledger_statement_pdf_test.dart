import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/services/ledger_statement_service.dart';
import 'package:milano_orders/theme/brand_config.dart';

/// The statement's layout only fails at render time — an over-wide table or a
/// row that cannot be laid out throws when the document is built, not when it
/// is described. So build a real multi-page one and make sure it comes out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a long statement renders to a multi-page PDF', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final shopId = await db.shopDao.upsertShop(ShopsCompanion.insert(
      name: 'Hotel Raj',
      area: const Value('Gandhipuram'),
    ));
    final productId =
        await db.productDao.upsertProduct(ProductsCompanion.insert(name: 'Bun'));

    // Enough rows to spill well past one page.
    for (var day = 1; day <= 60; day++) {
      final date = DateTime(2026, 1, 1).add(Duration(days: day));
      final order = await db.orderDao.getOrCreateOrder(shopId, date);
      await db.orderDao.replaceOrderLines(order.id, [
        OrderLinesCompanion.insert(
            orderId: order.id, productId: productId, qty: 3, unitPrice: 425.50),
      ]);
      if (day % 7 == 0) {
        await db.ledgerDao.recordPayment(
          shopId: shopId,
          amount: 5000,
          paidAt: date,
          mode: PaymentMode.upi,
          note: 'Weekly settlement against outstanding bills',
        );
      }
    }

    final entries = await db.ledgerDao.watchShopLedger(shopId).first;
    final shop = await db.shopDao.getShop(shopId);
    final data = buildStatementData(
      entries: entries,
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 3, 31),
      shopOpeningBalance: 0.0,
    );
    expect(data.rows.length, greaterThan(60));

    final bytes = await buildStatementPdf(
      brand: BrandConfig.milano,
      shop: shop!,
      business: BusinessInfoData(
        id: 1,
        name: 'Cafe Milano',
        address: '12 Mill Road',
        phone: '99999 88888',
      ),
      data: data,
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 3, 31),
    );

    expect(bytes.lengthInBytes, greaterThan(1000));
    // %PDF header — it really is a document, not an empty buffer.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
