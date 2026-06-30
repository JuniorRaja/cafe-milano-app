import 'package:drift/drift.dart';
import 'shops.dart';

class DailyOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  DateTimeColumn get orderDate => dateTime()();
  BoolColumn get isConfirmed => boolean().withDefault(const Constant(false))();
}
