import 'package:drift/drift.dart';
import 'daily_orders.dart';
import 'products.dart';

class OrderLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(DailyOrders, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get qty => integer()();
  RealColumn get unitPrice => real()();
}
