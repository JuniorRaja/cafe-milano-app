import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

final ordersForDateProvider =
    StreamProvider.family<List<DailyOrder>, DateTime>((ref, date) {
  return ref.watch(databaseProvider).orderDao.watchShopOrdersForDate(date);
});

final orderWithLinesProvider =
    StreamProvider.family<OrderWithLines?, int>((ref, orderId) {
  return ref.watch(databaseProvider).orderDao.watchOrderWithLines(orderId);
});

final orderSummariesForDateProvider =
    StreamProvider.family<List<OrderDaySummary>, DateTime>((ref, date) {
  return ref.watch(databaseProvider).orderDao.watchOrderSummariesForDate(date);
});
