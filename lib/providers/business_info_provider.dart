import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

final businessInfoProvider = StreamProvider<BusinessInfoData?>((ref) {
  return ref.watch(databaseProvider).businessInfoDao.watchBusinessInfo();
});
