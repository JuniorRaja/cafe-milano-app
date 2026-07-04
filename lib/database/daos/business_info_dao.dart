part of '../app_database.dart';

@DriftAccessor(tables: [BusinessInfo])
class BusinessInfoDao extends DatabaseAccessor<AppDatabase>
    with _$BusinessInfoDaoMixin {
  BusinessInfoDao(super.db);

  Stream<BusinessInfoData?> watchBusinessInfo() =>
      (select(businessInfo)..where((t) => t.id.equals(1)))
          .watchSingleOrNull();

  Future<void> upsertBusinessInfo(BusinessInfoCompanion companion) =>
      into(businessInfo)
          .insertOnConflictUpdate(companion.copyWith(id: const Value(1)));
}
