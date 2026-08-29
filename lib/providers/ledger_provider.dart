import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

/// Family key for [shopLedgerProvider]. A record gets structural equality
/// for free, so re-watching with the same filters doesn't resubscribe.
typedef ShopLedgerQuery = ({
  int shopId,
  DateTimeRange? range,
  BillStatus? status,
  LedgerType? type,
});

final shopLedgerProvider =
    StreamProvider.autoDispose.family<List<LedgerEntry>, ShopLedgerQuery>((ref, query) {
  final db = ref.watch(databaseProvider);
  return db.ledgerDao.watchShopLedger(
    query.shopId,
    rangeStart: query.range?.start,
    rangeEnd: query.range?.end,
    status: query.status,
    type: query.type,
  );
});

final shopStatsProvider =
    StreamProvider.autoDispose.family<ShopLedgerStats, int>((ref, shopId) {
  final db = ref.watch(databaseProvider);
  return db.ledgerDao.watchShopStats(shopId);
});

/// Payment status for every bill on one date, keyed by order id. One query
/// for the whole billing list rather than one per row, and a stream so the
/// chips repaint when a payment is recorded from anywhere else in the app.
final billDuesForDateProvider =
    StreamProvider.autoDispose.family<Map<int, BillDue>, DateTime>((ref, date) {
  final db = ref.watch(databaseProvider);
  return db.ledgerDao.watchBillDuesForDate(date);
});

/// Shops that still owe money, largest first. The dashboard card sums this
/// same list, so the headline figure and the list behind it are one number.
final outstandingByShopProvider = StreamProvider<List<ShopOutstanding>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.ledgerDao.watchOutstandingByShop();
});
