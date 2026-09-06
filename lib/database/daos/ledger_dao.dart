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

/// The one rule for "is this entry inside the requested period", shared by the
/// ledger screen's date filter and the PDF statement so the two can never
/// disagree about an entry on a boundary day.
///
/// Both ends are inclusive whole days. The end matters: a bill is dated at
/// midnight but a payment carries the wall-clock time it was recorded, so
/// comparing against the end day's midnight would drop a payment made on the
/// last day of the period — and a statement that quietly loses today's payment
/// is worse than useless in front of a shop.
bool ledgerEntryInRange(LedgerEntry entry, DateTime? start, DateTime? end) {
  if (start != null) {
    final startDay = DateTime(start.year, start.month, start.day);
    if (entry.date.isBefore(startDay)) return false;
  }
  if (end != null) {
    final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    if (entry.date.isAfter(endDay)) return false;
  }
  return true;
}

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

/// One bill's money position — status plus the amounts behind it, so a caller
/// that needs "what is still due on this bill" does not have to re-query for it.
class BillDue {
  final double total;
  final double allocated;
  final BillStatus status;

  const BillDue({
    required this.total,
    required this.allocated,
    required this.status,
  });

  double get amountDue => total - allocated;
}

/// What one shop still owes, for the receivables list and its dashboard total.
class ShopOutstanding {
  final int shopId;
  final String shopName;
  final String? area;
  final double outstanding;

  /// The date of this shop's oldest bill that is not fully settled. Null when
  /// the shop owes only an opening balance, which carries no date.
  final DateTime? oldestUnpaidAt;

  const ShopOutstanding({
    required this.shopId,
    required this.shopName,
    required this.outstanding,
    this.area,
    this.oldestUnpaidAt,
  });

  /// How long the oldest unsettled bill has been standing, against [asOf].
  int? ageInDays(DateTime asOf) => oldestUnpaidAt == null
      ? null
      : asOf.difference(oldestUnpaidAt!).inDays;
}

/// Money that moved inside a period. Billed is what went out as bills,
/// collected is what came back — the two halves of a month, side by side.
class PeriodMoney {
  final double billed;
  final double collected;

  const PeriodMoney({required this.billed, required this.collected});

  static const empty = PeriodMoney(billed: 0, collected: 0);

  /// Positive when more was collected than billed — a month spent catching up
  /// on old debt rather than falling further behind.
  double get net => collected - billed;
}

/// Every shop's outstanding folded into one figure, for the drawer card.
///
/// Deliberately derived from the same rows [LedgerDao.watchOutstandingByShop]
/// returns rather than from a second query. The drawer's headline and the
/// receivables list behind it are then one computation, and cannot drift apart
/// the way two independently-written SUMs eventually do.
class OutstandingSummary {
  final double total;
  final int shopCount;

  /// The oldest unsettled bill across every shop that owes.
  final DateTime? oldestUnpaidAt;

  const OutstandingSummary({
    required this.total,
    required this.shopCount,
    this.oldestUnpaidAt,
  });

  static const empty = OutstandingSummary(total: 0.0, shopCount: 0);

  int? ageInDays(DateTime asOf) => oldestUnpaidAt == null
      ? null
      : asOf.difference(oldestUnpaidAt!).inDays;
}

@DriftAccessor(tables: [Payments, PaymentAllocations, DailyOrders, OrderLines, Shops])
class LedgerDao extends DatabaseAccessor<AppDatabase> with _$LedgerDaoMixin {
  LedgerDao(super.db);

  BillStatus _billStatusFor(double total, double allocated) {
    // A zero-total order owes nothing, so it is vacuously settled. This must be
    // checked first: opening the order-entry screen creates an empty order row,
    // and those would otherwise read Unpaid forever.
    if (total <= _moneyEpsilon) return BillStatus.paid;
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

  /// Every real bill on one date with its status, in a single query.
  ///
  /// The billing screen is a list, so a per-row status lookup would be an N+1
  /// of exactly the kind doc 04 removed from the dashboard. Callers fetch this
  /// map once per date and look up each row.
  ///
  /// Orders with no payment status are simply absent, and the caller shows no
  /// chip for them. Two kinds never have one: a zero-line order (opening the
  /// order-entry screen creates the row before anything is typed) is not a
  /// bill, and an order before its shop's opening-balance cutoff is pre-ledger
  /// history already folded into that shop's opening balance. Neither can ever
  /// be allocated against, so neither is Unpaid — they are simply not bills
  /// this ledger tracks, exactly as [watchShopLedger] treats them.
  Stream<Map<int, BillDue>> watchBillDuesForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final query = customSelect(
      'SELECT o.id AS order_id, '
      '(SELECT COALESCE(SUM(ol.qty * ol.unit_price), 0.0) FROM order_lines ol WHERE ol.order_id = o.id) AS total, '
      '(SELECT COALESCE(SUM(pa.amount), 0.0) FROM payment_allocations pa WHERE pa.order_id = o.id) AS allocated '
      'FROM daily_orders o '
      'INNER JOIN shops s ON s.id = o.shop_id '
      'WHERE o.order_date = ? '
      'AND (s.opening_balance_at IS NULL OR o.order_date >= s.opening_balance_at)',
      variables: [Variable.withDateTime(dayStart)],
      readsFrom: {dailyOrders, orderLines, paymentAllocations, shops},
    );

    return query.watch().map((rows) {
      final dues = <int, BillDue>{};
      for (final row in rows) {
        final total = row.read<double>('total');
        if (total <= _moneyEpsilon) continue;
        final allocated = row.read<double>('allocated');
        dues[row.read<int>('order_id')] = BillDue(
          total: total,
          allocated: allocated,
          status: _billStatusFor(total, allocated),
        );
      }
      return dues;
    });
  }

  /// Every shop that still owes money, largest first, in one query.
  ///
  /// The dashboard total is the sum of exactly these rows, so the card and the
  /// list cannot disagree — they are one computation, not two.
  ///
  /// "Outstanding" is the same figure [watchShopStats] derives per shop:
  /// opening balance, plus bills on or after that shop's cutoff, minus
  /// everything collected. So opening balances count, bills before a shop's
  /// cutoff do not (they are inside its opening balance already), and an
  /// unallocated payment still reduces the total — it is money in hand
  /// whether or not it has been pointed at a specific bill yet.
  ///
  /// A shop in credit is left out rather than netted off: a credit is not a
  /// receivable, and subtracting it would understate what is collectable.
  /// Inactive shops stay in — money owed is owed whether or not the shop is
  /// still being delivered to.
  Stream<List<ShopOutstanding>> watchOutstandingByShop() {
    final query = customSelect(
      'SELECT s.id AS shop_id, s.name AS name, s.area AS area, '
      'COALESCE(s.opening_balance, 0.0) '
      '+ (SELECT COALESCE(SUM(ol.qty * ol.unit_price), 0.0) '
      '   FROM order_lines ol INNER JOIN daily_orders o ON ol.order_id = o.id '
      '   WHERE o.shop_id = s.id '
      '   AND (s.opening_balance_at IS NULL OR o.order_date >= s.opening_balance_at)) '
      '- (SELECT COALESCE(SUM(p.amount), 0.0) FROM payments p WHERE p.shop_id = s.id) '
      'AS outstanding, '
      // The oldest bill this shop has not fully settled. A zero-total order is
      // excluded by the same > epsilon test the rest of this DAO uses: opening
      // order entry creates an empty order row, and an empty row is not an
      // ancient unpaid bill.
      '(SELECT MIN(o.order_date) FROM daily_orders o '
      '   WHERE o.shop_id = s.id '
      '   AND (s.opening_balance_at IS NULL OR o.order_date >= s.opening_balance_at) '
      '   AND (SELECT COALESCE(SUM(ol.qty * ol.unit_price), 0.0) '
      '        FROM order_lines ol WHERE ol.order_id = o.id) '
      '     - (SELECT COALESCE(SUM(pa.amount), 0.0) '
      '        FROM payment_allocations pa WHERE pa.order_id = o.id) > ?'
      ') AS oldest_unpaid '
      'FROM shops s ORDER BY outstanding DESC',
      variables: [Variable.withReal(_moneyEpsilon)],
      readsFrom: {shops, dailyOrders, orderLines, payments, paymentAllocations},
    );

    return query.watch().map((rows) => rows
        .map((row) => ShopOutstanding(
              shopId: row.read<int>('shop_id'),
              shopName: row.read<String>('name'),
              area: row.read<String?>('area'),
              outstanding: row.read<double>('outstanding'),
              oldestUnpaidAt: row.read<DateTime?>('oldest_unpaid'),
            ))
        .where((s) => s.outstanding > _moneyEpsilon)
        .toList());
  }

  /// The all-shops receivables position, as one figure with its supporting
  /// counts. This is what the drawer card shows, and until doc 10b it was a
  /// number the app could not display at all.
  ///
  /// Folded from [watchOutstandingByShop] rather than queried separately, so
  /// the headline is the sum of the list by construction. A shop in credit is
  /// already excluded there and so contributes nothing here either.
  Stream<OutstandingSummary> watchOutstandingSummary() {
    return watchOutstandingByShop().map((shops) {
      if (shops.isEmpty) return OutstandingSummary.empty;

      DateTime? oldest;
      var total = 0.0;
      for (final shop in shops) {
        total += shop.outstanding;
        final at = shop.oldestUnpaidAt;
        if (at != null && (oldest == null || at.isBefore(oldest))) oldest = at;
      }

      return OutstandingSummary(
        total: total,
        shopCount: shops.length,
        oldestUnpaidAt: oldest,
      );
    });
  }

  /// What was collected and billed inside a period, for the Finances quick
  /// stats. Read-only and additive, one aggregate rather than a per-shop read.
  ///
  /// "Billed" counts real bills only — a zero-total order is the empty row the
  /// order-entry screen creates before anything is typed, and is not a bill,
  /// exactly as the rest of this DAO treats it. Bills before a shop's
  /// opening-balance cutoff are already inside that balance and are skipped.
  Stream<PeriodMoney> watchPeriodMoney(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);

    final query = customSelect(
      'SELECT '
      '(SELECT COALESCE(SUM(p.amount), 0.0) FROM payments p '
      '   WHERE p.paid_at >= ? AND p.paid_at <= ?) AS collected, '
      '(SELECT COALESCE(SUM(t.total), 0.0) FROM ('
      '   SELECT (SELECT COALESCE(SUM(ol.qty * ol.unit_price), 0.0) '
      '           FROM order_lines ol WHERE ol.order_id = o.id) AS total '
      '   FROM daily_orders o INNER JOIN shops s ON s.id = o.shop_id '
      '   WHERE o.order_date >= ? AND o.order_date <= ? '
      '   AND (s.opening_balance_at IS NULL '
      '        OR o.order_date >= s.opening_balance_at)'
      ' ) t WHERE t.total > ?) AS billed',
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
        Variable.withReal(_moneyEpsilon),
      ],
      readsFrom: {payments, dailyOrders, orderLines, shops},
    );

    return query.watchSingle().map((row) => PeriodMoney(
          collected: row.read<double>('collected'),
          billed: row.read<double>('billed'),
        ));
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
          // Opening the order-entry screen inserts an order row before anything
          // is typed, so a shop accumulates empty orders. They are not bills and
          // must not reach the ledger; skipping them cannot shift the running
          // balance, which they contribute 0.0 to by definition.
          if (amount <= _moneyEpsilon) continue;
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
        return ledgerEntryInRange(e, rangeStart, rangeEnd);
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

  /// Writes at most [available] against one bill, never more than that bill
  /// still owes, and returns what it actually allocated. Every allocation this
  /// DAO makes goes through here, so the "never over-allocate a bill" rule has
  /// exactly one home regardless of which path asked for it.
  Future<double> _allocate(int paymentId, int orderId, double available) async {
    if (available <= _moneyEpsilon) return 0.0;
    final total = await _getOrderTotal(orderId);
    if (total <= _moneyEpsilon) return 0.0;
    final due = total - await _getAllocatedAmount(orderId);
    if (due <= _moneyEpsilon) return 0.0;

    final toAllocate = available < due ? available : due;
    await into(paymentAllocations).insert(PaymentAllocationsCompanion.insert(
      paymentId: paymentId,
      orderId: orderId,
      amount: toAllocate,
    ));
    return toAllocate;
  }

  /// Inserts the payment, then auto-allocates FIFO against this shop's
  /// oldest unpaid/partially-paid bills (respecting the opening-balance
  /// cutoff). Whole thing in one transaction. Any amount left over after all
  /// outstanding bills are settled sits unallocated — an overpayment or
  /// advance, surfaced by doc 06, not an error here.
  ///
  /// [priorityOrderId] settles that one bill before FIFO runs — the
  /// Mark-as-Paid path from the billing screen, where the money is for a named
  /// bill rather than for "whatever is oldest". Anything left after that bill
  /// is settled still flows FIFO across the rest, so raising the amount above
  /// the named bill's due behaves the way an ordinary payment would.
  Future<int> recordPayment({
    required int shopId,
    required double amount,
    required DateTime paidAt,
    required PaymentMode mode,
    String? note,
    int? priorityOrderId,
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
      if (priorityOrderId != null) {
        remaining -= await _allocate(paymentId, priorityOrderId, remaining);
      }
      for (final order in orders) {
        if (remaining <= _moneyEpsilon) break;
        // A priority bill already settled above is skipped here for free —
        // it now owes nothing, so _allocate returns 0.
        remaining -= await _allocate(paymentId, order.id, remaining);
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
