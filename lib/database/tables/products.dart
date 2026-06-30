import 'package:drift/drift.dart';

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get unit => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
