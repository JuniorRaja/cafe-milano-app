import 'package:drift/drift.dart';
import 'shops.dart';

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  DateTimeColumn get paidAt => dateTime()();
  RealColumn get amount => real()();
  TextColumn get mode => text()();
  TextColumn get note => text().nullable()();
}
