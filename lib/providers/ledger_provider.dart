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
    StreamProvider.family<List<LedgerEntry>, ShopLedgerQuery>((ref, query) {
  final db = ref.watch(databaseProvider);
  return db.ledgerDao.watchShopLedger(
    query.shopId,
    rangeStart: query.range?.start,
    rangeEnd: query.range?.end,
    status: query.status,
    type: query.type,
  );
});

final shopStatsProvider = StreamProvider.family<ShopLedgerStats, int>((ref, shopId) {
  final db = ref.watch(databaseProvider);
  return db.ledgerDao.watchShopStats(shopId);
});

final billStatusProvider = FutureProvider.family<BillStatus, int>((ref, orderId) {
  final db = ref.watch(databaseProvider);
  return db.ledgerDao.getBillStatus(orderId);
});
