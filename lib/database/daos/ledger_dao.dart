part of '../app_database.dart';

// SQLite REAL columns accumulate floating-point error (sum(allocations) ==
// orderTotal can be false by 1e-13). Every money comparison in this file
// routes through this one epsilon so "paid to the last paisa" reliably reads
// as Paid rather than drifting to Partial.
const _moneyEpsilon = 0.005;
bool _moneyEquals(double a, double b) => (a - b).abs() < _moneyEpsilon;

enum PaymentMode { cash, upi, bank, cheque }

enum LedgerType { bill, payment }

enum BillStatus { unpaid, partial, paid }

class LedgerEntry {
  final LedgerType type;
  final DateTime date;
  final double amount;
  /// For a bill, how much of it has been settled by allocations. Always 0 on a
  /// payment row — a payment is not itself "allocated against".
  final double allocatedAmount;
  final double runningBalance;
  final int? orderId;
  final int? paymentId;
  final BillStatus? billStatus;
  final PaymentMode? paymentMode;
  final String? note;

  const LedgerEntry({
    required this.type,
    required this.date,
    required this.amount,
    required this.runningBalance,
    this.allocatedAmount = 0.0,
    this.orderId,
    this.paymentId,
    this.billStatus,
    this.paymentMode,
    this.note,
  });

  /// What is still owed on this bill. Meaningless on a payment row.
  double get amountDue => amount - allocatedAmount;
}

class ShopLedgerStats {
  final double totalBilled;
  final double totalCollected;
  final double outstanding;
  final DateTime? lastPaymentAt;

  const ShopLedgerStats({
    required this.totalBilled,
    required this.totalCollected,
    required this.outstanding,
    this.lastPaymentAt,
  });
}

@DriftAccessor(tables: [Payments, PaymentAllocations, DailyOrders, OrderLines, Shops])
class LedgerDao extends DatabaseAccessor<AppDatabase> with _$LedgerDaoMixin {
  LedgerDao(super.db);

  BillStatus _billStatusFor(double total, double allocated) {
    if (allocated <= _moneyEpsilon) return BillStatus.unpaid;
    if (_moneyEquals(allocated, total)) return BillStatus.paid;
    return BillStatus.partial;
  }

  Future<double> _getOrderTotal(int orderId) async {
    final query = customSelect(
      'SELECT COALESCE(SUM(qty * unit_price), 0.0) AS total '
      'FROM order_lines WHERE order_id = ?',
      variables: [Variable.withInt(orderId)],
      readsFrom: {orderLines},
    );
    final row = await query.getSingle();
    return row.read<double>('total');
  }

  Future<double> _getAllocatedAmount(int orderId) async {
    final query = customSelect(
      'SELECT COALESCE(SUM(amount), 0.0) AS total '
      'FROM payment_allocations WHERE order_id = ?',
      variables: [Variable.withInt(orderId)],
      readsFrom: {paymentAllocations},
    );
    final row = await query.getSingle();
    return row.read<double>('total');
  }

  /// Derives Paid / Partial / Unpaid for one bill. Never stored — always
  /// computed from allocations vs. the order's line total.
  Future<BillStatus> getBillStatus(int orderId) async {
    final total = await _getOrderTotal(orderId);
    final allocated = await _getAllocatedAmount(orderId);
    return _billStatusFor(total, allocated);
  }

  /// Chronological interleave of bills (debits) and payments (credits) for
  /// one shop, with a running balance computed here in Dart. [rangeStart] /
  /// [rangeEnd] narrow which entries are *returned*, but the running balance
  /// on each entry always reflects the full history — filtering the view
  /// must never make the balance look reset.
  ///
  /// The shop's opening balance / cutoff are read once per subscription,
  /// not watched: per the data model, `openingBalance` is only editable on a
  /// new shop or while still null, so it cannot change again once a ledger
  /// screen is open on that shop.
  Stream<List<LedgerEntry>> watchShopLedger(
    int shopId, {
    DateTime? rangeStart,
    DateTime? rangeEnd,
    BillStatus? status,
    LedgerType? type,
  }) async* {
    final shop = await (select(shops)..where((s) => s.id.equals(shopId))).getSingle();
    final openingBalance = shop.openingBalance ?? 0.0;
    // Bills before the cutoff are pre-ledger history folded into
    // openingBalance; a null cutoff (epoch) excludes nothing.
    final cutoff = shop.openingBalanceAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    final query = customSelect(
      "SELECT 'bill' AS entry_type, o.id AS ref_id, o.order_date AS entry_date, "
      "(SELECT COALESCE(SUM(ol.qty * ol.unit_price), 0.0) FROM order_lines ol WHERE ol.order_id = o.id) AS amount, "
      "(SELECT COALESCE(SUM(pa.amount), 0.0) FROM payment_allocations pa WHERE pa.order_id = o.id) AS allocated, "
      "NULL AS mode, NULL AS note "
      "FROM daily_orders o "
      "WHERE o.shop_id = ? AND o.order_date >= ? "
      "UNION ALL "
      "SELECT 'payment' AS entry_type, p.id AS ref_id, p.paid_at AS entry_date, "
      "p.amount AS amount, NULL AS allocated, p.mode AS mode, p.note AS note "
      "FROM payments p WHERE p.shop_id = ? "
      "ORDER BY entry_date ASC, entry_type ASC",
      variables: [
        Variable.withInt(shopId),
        Variable.withDateTime(cutoff),
        Variable.withInt(shopId),
      ],
      readsFrom: {dailyOrders, orderLines, paymentAllocations, payments},
    );

    yield* query.watch().map((rows) {
      final entries = <LedgerEntry>[];
      var runningBalance = openingBalance;
      for (final row in rows) {
        final entryType = row.read<String>('entry_type');
        final date = row.read<DateTime>('entry_date');
        final amount = row.read<double>('amount');
        if (entryType == 'bill') {
          final allocated = row.read<double>('allocated');
          runningBalance += amount;
          entries.add(LedgerEntry(
            type: LedgerType.bill,
            date: date,
            amount: amount,
            allocatedAmount: allocated,
            runningBalance: runningBalance,
            orderId: row.read<int>('ref_id'),
            billStatus: _billStatusFor(amount, allocated),
          ));
        } else {
          runningBalance -= amount;
          entries.add(LedgerEntry(
            type: LedgerType.payment,
            date: date,
            amount: amount,
            runningBalance: runningBalance,
            paymentId: row.read<int>('ref_id'),
            paymentMode: PaymentMode.values.byName(row.read<String>('mode')),
            note: row.read<String?>('note'),
          ));
        }
      }

      return entries.where((e) {
        if (status != null && (e.type != LedgerType.bill || e.billStatus != status)) {
          return false;
        }
        if (type != null && e.type != type) return false;
        if (rangeStart != null) {
          final startDay = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
          if (e.date.isBefore(startDay)) return false;
        }
        if (rangeEnd != null) {
          final endDay = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
          if (e.date.isAfter(endDay)) return false;
        }
        return true;
      }).toList();
    });
  }

  /// totalBilled / totalCollected / outstanding / lastPaymentAt for one shop,
  /// as a single reactive query so it recomputes whenever a payment, order,
  /// or order line for this shop changes.
  Stream<ShopLedgerStats> watchShopStats(int shopId) {
    final query = customSelect(
      'SELECT s.opening_balance AS opening_balance, '
      '(SELECT COALESCE(SUM(ol.qty * ol.unit_price), 0.0) '
      ' FROM order_lines ol INNER JOIN daily_orders o ON ol.order_id = o.id '
      ' WHERE o.shop_id = s.id '
      ' AND (s.opening_balance_at IS NULL OR o.order_date >= s.opening_balance_at)'
      ') AS total_billed, '
      '(SELECT COALESCE(SUM(amount), 0.0) FROM payments WHERE shop_id = s.id) AS total_collected, '
      '(SELECT MAX(paid_at) FROM payments WHERE shop_id = s.id) AS last_payment_at '
      'FROM shops s WHERE s.id = ?',
      variables: [Variable.withInt(shopId)],
      readsFrom: {shops, dailyOrders, orderLines, payments},
    );
    return query.watchSingle().map((row) {
      final openingBalance = row.read<double?>('opening_balance') ?? 0.0;
      final totalBilled = row.read<double>('total_billed');
      final totalCollected = row.read<double>('total_collected');
      return ShopLedgerStats(
        totalBilled: totalBilled,
        totalCollected: totalCollected,
        outstanding: openingBalance + totalBilled - totalCollected,
        lastPaymentAt: row.read<DateTime?>('last_payment_at'),
      );
    });
  }

  /// Inserts the payment, then auto-allocates FIFO against this shop's
  /// oldest unpaid/partially-paid bills (respecting the opening-balance
  /// cutoff). Whole thing in one transaction. Any amount left over after all
  /// outstanding bills are settled sits unallocated — an overpayment or
  /// advance, surfaced by doc 06, not an error here.
  Future<int> recordPayment({
    required int shopId,
    required double amount,
    required DateTime paidAt,
    required PaymentMode mode,
    String? note,
  }) {
    return transaction(() async {
      final paymentId = await into(payments).insert(PaymentsCompanion.insert(
        shopId: shopId,
        paidAt: paidAt,
        amount: amount,
        mode: mode.name,
        note: Value(note),
      ));

      final shop = await (select(shops)..where((s) => s.id.equals(shopId))).getSingle();
      final cutoff = shop.openingBalanceAt;

      final ordersQuery = select(dailyOrders)
        ..where((o) => o.shopId.equals(shopId))
        ..orderBy([(o) => OrderingTerm(expression: o.orderDate)]);
      if (cutoff != null) {
        ordersQuery.where((o) => o.orderDate.isBiggerOrEqualValue(cutoff));
      }
      final orders = await ordersQuery.get();

      var remaining = amount;
      for (final order in orders) {
        if (remaining <= _moneyEpsilon) break;
        final total = await _getOrderTotal(order.id);
        if (total <= _moneyEpsilon) continue;
        final allocated = await _getAllocatedAmount(order.id);
        final due = total - allocated;
        if (due <= _moneyEpsilon) continue;

        final toAllocate = remaining < due ? remaining : due;
        await into(paymentAllocations).insert(PaymentAllocationsCompanion.insert(
          paymentId: paymentId,
          orderId: order.id,
          amount: toAllocate,
        ));
        remaining -= toAllocate;
      }

      return paymentId;
    });
  }

  /// Allocations then the payment itself, one transaction — the correction
  /// path for a mis-recorded payment is delete and re-record, not edit.
  Future<void> deletePayment(int paymentId) {
    return transaction(() async {
      await (delete(paymentAllocations)..where((a) => a.paymentId.equals(paymentId))).go();
      await (delete(payments)..where((p) => p.id.equals(paymentId))).go();
    });
  }
}
