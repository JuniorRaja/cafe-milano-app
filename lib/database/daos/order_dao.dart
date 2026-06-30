part of '../app_database.dart';

class KitchenRawLine {
  final int shopId;
  final int productId;
  final int qty;
  const KitchenRawLine({
    required this.shopId,
    required this.productId,
    required this.qty,
  });
}

class OrderWithLines {
  final DailyOrder order;
  final List<OrderLine> lines;
  const OrderWithLines({required this.order, required this.lines});
}

class OrderDaySummary {
  final DailyOrder order;
  final int itemCount; // distinct product line count
  final double total;
  const OrderDaySummary({required this.order, required this.itemCount, required this.total});
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

  Future<void> replaceOrderLines(int orderId, List<OrderLinesCompanion> lines) {
    return transaction(() async {
      await (delete(orderLines)..where((l) => l.orderId.equals(orderId))).go();
      for (final line in lines) {
        if (line.qty.value > 0) {
          await into(orderLines).insert(line.copyWith(orderId: Value(orderId)));
        }
      }
    });
  }

  Future<void> setConfirmed(int orderId, bool confirmed) =>
      (update(dailyOrders)..where((o) => o.id.equals(orderId)))
          .write(DailyOrdersCompanion(isConfirmed: Value(confirmed)));

  Stream<List<OrderDaySummary>> watchOrderSummariesForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final query =
        (select(dailyOrders)..where((o) => o.orderDate.equals(dayStart))).join([
      leftOuterJoin(orderLines, orderLines.orderId.equalsExp(dailyOrders.id)),
    ]);
    return query.watch().map((rows) {
      final Map<int, ({DailyOrder order, int items, double total})> acc = {};
      for (final row in rows) {
        final order = row.readTable(dailyOrders);
        final line = row.readTableOrNull(orderLines);
        final prev = acc[order.id];
        if (prev == null) {
          acc[order.id] = (
            order: order,
            items: line != null ? 1 : 0,
            total: line != null ? line.qty * line.unitPrice : 0.0,
          );
        } else if (line != null) {
          acc[order.id] = (
            order: order,
            items: prev.items + 1,
            total: prev.total + line.qty * line.unitPrice,
          );
        }
      }
      return acc.values
          .map((e) => OrderDaySummary(
                order: e.order,
                itemCount: e.items,
                total: e.total,
              ))
          .toList();
    });
  }

  Stream<List<KitchenRawLine>> watchKitchenLinesForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final query =
        (select(dailyOrders)..where((o) => o.orderDate.equals(dayStart))).join([
      innerJoin(orderLines, orderLines.orderId.equalsExp(dailyOrders.id)),
    ]);
    return query.watch().map(
          (rows) => rows
              .map(
                (r) => KitchenRawLine(
                  shopId: r.readTable(dailyOrders).shopId,
                  productId: r.readTable(orderLines).productId,
                  qty: r.readTable(orderLines).qty,
                ),
              )
              .toList(),
        );
  }

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
