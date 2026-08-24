import 'package:milano_orders/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _freshDb() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  group('LedgerDao', () {
    late AppDatabase db;
    late int shopId;
    late int productId;

    setUp(() async {
      db = _freshDb();
      shopId = await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Hotel Raj'));
      productId = await db.productDao.upsertProduct(ProductsCompanion.insert(name: 'Bun'));
    });
    tearDown(() => db.close());

    Future<int> bill(DateTime date, double amount) async {
      final order = await db.orderDao.getOrCreateOrder(shopId, date);
      await db.orderDao.replaceOrderLines(order.id, [
        OrderLinesCompanion.insert(orderId: order.id, productId: productId, qty: 1, unitPrice: amount),
      ]);
      return order.id;
    }

    test('FIFO settles the oldest bills first, leaving the last one partial', () async {
      final o1 = await bill(DateTime(2026, 1, 1), 1300);
      final o2 = await bill(DateTime(2026, 1, 2), 1300);
      final o3 = await bill(DateTime(2026, 1, 3), 1300);
      final o4 = await bill(DateTime(2026, 1, 4), 1300); // 4 x 1300 = 5200

      await db.ledgerDao.recordPayment(
        shopId: shopId, amount: 5000, paidAt: DateTime(2026, 1, 5), mode: PaymentMode.cash);

      expect(await db.ledgerDao.getBillStatus(o1), BillStatus.paid);
      expect(await db.ledgerDao.getBillStatus(o2), BillStatus.paid);
      expect(await db.ledgerDao.getBillStatus(o3), BillStatus.paid);
      expect(await db.ledgerDao.getBillStatus(o4), BillStatus.partial);

      final stats = await db.ledgerDao.watchShopStats(shopId).first;
      expect(stats.outstanding, closeTo(200, 0.001));
    });

    test('a payment larger than all outstanding bills leaves the remainder unallocated, not negative', () async {
      final o1 = await bill(DateTime(2026, 1, 1), 500);

      await db.ledgerDao.recordPayment(
        shopId: shopId, amount: 2000, paidAt: DateTime(2026, 1, 2), mode: PaymentMode.upi);

      expect(await db.ledgerDao.getBillStatus(o1), BillStatus.paid);
      final stats = await db.ledgerDao.watchShopStats(shopId).first;
      expect(stats.totalCollected, 2000);
      // The 1500 overpayment shows up as negative outstanding (a credit), never
      // as a phantom unpaid bill or a clamped/lost amount.
      expect(stats.outstanding, closeTo(-1500, 0.001));
    });

    test('a payment against a shop with zero unpaid bills persists with no allocations', () async {
      final paymentId = await db.ledgerDao.recordPayment(
        shopId: shopId, amount: 1000, paidAt: DateTime(2026, 1, 1), mode: PaymentMode.cash);

      final stats = await db.ledgerDao.watchShopStats(shopId).first;
      expect(stats.totalCollected, 1000);
      expect(stats.totalBilled, 0);

      final entries = await db.ledgerDao.watchShopLedger(shopId).first;
      expect(entries, hasLength(1));
      expect(entries.first.type, LedgerType.payment);
      expect(entries.first.paymentId, paymentId);
    });

    test('bills before openingBalanceAt are never allocated against', () async {
      await db.shopDao.upsertShop(ShopsCompanion(
        id: Value(shopId),
        name: const Value('Hotel Raj'),
        openingBalance: const Value(0),
        openingBalanceAt: Value(DateTime(2026, 2, 1)),
      ));
      final preLedger = await bill(DateTime(2026, 1, 15), 1000); // before cutoff
      final postLedger = await bill(DateTime(2026, 2, 10), 1000); // after cutoff

      await db.ledgerDao.recordPayment(
        shopId: shopId, amount: 1000, paidAt: DateTime(2026, 2, 15), mode: PaymentMode.cash);

      expect(await db.ledgerDao.getBillStatus(preLedger), BillStatus.unpaid);
      expect(await db.ledgerDao.getBillStatus(postLedger), BillStatus.paid);
    });

    test('deleting a payment restores outstanding to exactly its prior value', () async {
      await bill(DateTime(2026, 1, 1), 1000);
      final before = (await db.ledgerDao.watchShopStats(shopId).first).outstanding;

      final paymentId = await db.ledgerDao.recordPayment(
        shopId: shopId, amount: 400, paidAt: DateTime(2026, 1, 2), mode: PaymentMode.cash);
      final afterPayment = (await db.ledgerDao.watchShopStats(shopId).first).outstanding;
      expect(afterPayment, closeTo(before - 400, 0.001));

      await db.ledgerDao.deletePayment(paymentId);
      final afterDelete = (await db.ledgerDao.watchShopStats(shopId).first).outstanding;
      expect(afterDelete, closeTo(before, 0.001));
    });

    test('a bill paid to the last paisa reads Paid despite float error, not Partial', () async {
      // 0.1 + 0.1 + 0.1 famously doesn't equal 0.3 exactly in binary floating point.
      final orderId = await bill(DateTime(2026, 1, 1), 0.3);
      for (var i = 0; i < 3; i++) {
        await db.ledgerDao.recordPayment(
          shopId: shopId, amount: 0.1, paidAt: DateTime(2026, 1, 2 + i), mode: PaymentMode.cash);
      }

      expect(await db.ledgerDao.getBillStatus(orderId), BillStatus.paid);
    });

    test('a second payment closes a Partial bill to Paid', () async {
      final orderId = await bill(DateTime(2026, 1, 1), 1000);
      await db.ledgerDao.recordPayment(
        shopId: shopId, amount: 600, paidAt: DateTime(2026, 1, 2), mode: PaymentMode.cash);
      expect(await db.ledgerDao.getBillStatus(orderId), BillStatus.partial);

      await db.ledgerDao.recordPayment(
        shopId: shopId, amount: 400, paidAt: DateTime(2026, 1, 3), mode: PaymentMode.cash);
      expect(await db.ledgerDao.getBillStatus(orderId), BillStatus.paid);
    });

    test('one payment spanning four days of bills appears once and settles all four', () async {
      final orders = <int>[];
      for (var i = 1; i <= 4; i++) {
        orders.add(await bill(DateTime(2026, 1, i), 500));
      }
      await db.ledgerDao.recordPayment(
        shopId: shopId, amount: 2000, paidAt: DateTime(2026, 1, 10), mode: PaymentMode.bank);

      final entries = await db.ledgerDao.watchShopLedger(shopId).first;
      final paymentEntries = entries.where((e) => e.type == LedgerType.payment).toList();
      expect(paymentEntries, hasLength(1));
      expect(paymentEntries.first.amount, 2000);
      for (final orderId in orders) {
        expect(await db.ledgerDao.getBillStatus(orderId), BillStatus.paid);
      }
    });

    test('running balance equals openingBalance + totalBilled - totalCollected', () async {
      await db.shopDao.upsertShop(ShopsCompanion(
        id: Value(shopId),
        name: const Value('Hotel Raj'),
        openingBalance: const Value(500),
        openingBalanceAt: Value(DateTime(2025, 12, 1)),
      ));
      await bill(DateTime(2026, 1, 1), 1000);
      await bill(DateTime(2026, 1, 2), 500);
      await db.ledgerDao.recordPayment(
        shopId: shopId, amount: 700, paidAt: DateTime(2026, 1, 3), mode: PaymentMode.cash);

      final entries = await db.ledgerDao.watchShopLedger(shopId).first;
      final stats = await db.ledgerDao.watchShopStats(shopId).first;

      expect(stats.outstanding, closeTo(500 + 1500 - 700, 0.001));
      expect(entries.last.runningBalance, closeTo(stats.outstanding, 0.001));
    });

    test('status filter and date filter combine correctly', () async {
      await bill(DateTime(2025, 1, 1), 500); // unpaid, but outside the date range below
      final recentUnpaid = await bill(DateTime(2026, 8, 20), 300);
      final recentPaidOrder = await bill(DateTime(2026, 8, 21), 200);
      await db.ledgerDao.recordPayment(
        shopId: shopId, amount: 200, paidAt: DateTime(2026, 8, 22), mode: PaymentMode.cash);

      final entries = await db.ledgerDao
          .watchShopLedger(
            shopId,
            rangeStart: DateTime(2026, 7, 24),
            rangeEnd: DateTime(2026, 8, 23),
            status: BillStatus.unpaid,
          )
          .first;

      expect(entries, hasLength(1));
      expect(entries.first.orderId, recentUnpaid);
      expect(entries.first.type, LedgerType.bill);
      expect(entries.any((e) => e.orderId == recentPaidOrder), isFalse);
    });
  });
}
