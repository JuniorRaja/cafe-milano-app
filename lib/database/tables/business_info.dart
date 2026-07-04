import 'package:drift/drift.dart';

@DataClassName('BusinessInfoData')
class BusinessInfo extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get logoPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
