part of '../app_database.dart';

class OrderWithLines {
  final DailyOrder order;
  final List<OrderLine> lines;
  const OrderWithLines({required this.order, required this.lines});
}

@DriftAccessor(tables: [DailyOrders, OrderLines])
class OrderDao extends DatabaseAccessor<AppDatabase> with _$OrderDaoMixin {
  OrderDao(super.db);

  Stream<List<DailyOrder>> watchShopOrdersForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    return (select(dailyOrders)
          ..where((o) => o.orderDate.equals(dayStart)))
        .watch();
  }

  // Join query so both tables are watched — reactive to line changes too.
  Stream<OrderWithLines?> watchOrderWithLines(int orderId) {
    final query = (select(dailyOrders)..where((o) => o.id.equals(orderId))).join([
      leftOuterJoin(orderLines, orderLines.orderId.equalsExp(dailyOrders.id)),
    ]);
    return query.watch().map((rows) {
      if (rows.isEmpty) return null;
      final order = rows.first.readTable(dailyOrders);
      final lines = rows
          .where((r) => r.readTableOrNull(orderLines) != null)
          .map((r) => r.readTable(orderLines))
          .toList();
      return OrderWithLines(order: order, lines: lines);
    });
  }

  Future<void> upsertOrderWithLines(
    DailyOrder order,
    List<OrderLinesCompanion> lines,
  ) {
    return transaction(() async {
      await into(dailyOrders).insertOnConflictUpdate(order.toCompanion(true));
      await (delete(orderLines)..where((l) => l.orderId.equals(order.id))).go();
      for (final line in lines) {
        if (line.qty.value > 0) {
          await into(orderLines).insert(line.copyWith(orderId: Value(order.id)));
        }
      }
    });
  }

  Future<void> setConfirmed(int orderId, bool confirmed) =>
      (update(dailyOrders)..where((o) => o.id.equals(orderId)))
          .write(DailyOrdersCompanion(isConfirmed: Value(confirmed)));

  Future<DailyOrder> getOrCreateOrder(int shopId, DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    return transaction(() async {
      final existing = await (select(dailyOrders)
            ..where(
              (o) => o.shopId.equals(shopId) & o.orderDate.equals(dayStart),
            ))
          .getSingleOrNull();
      if (existing != null) return existing;
      return into(dailyOrders).insertReturning(
        DailyOrdersCompanion.insert(shopId: shopId, orderDate: dayStart),
      );
    });
  }
}
