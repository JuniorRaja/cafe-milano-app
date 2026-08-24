import 'package:drift/drift.dart';
import 'payments.dart';
import 'daily_orders.dart';

class PaymentAllocations extends Table {
  IntColumn get paymentId => integer().references(Payments, #id)();
  IntColumn get orderId => integer().references(DailyOrders, #id)();
  RealColumn get amount => real()();

  @override
  Set<Column> get primaryKey => {paymentId, orderId};
}
