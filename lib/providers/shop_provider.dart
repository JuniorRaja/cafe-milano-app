import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

final activeShopsProvider = StreamProvider<List<Shop>>((ref) {
  return ref.watch(databaseProvider).shopDao.watchActiveShops();
});

final allShopsProvider = StreamProvider<List<Shop>>((ref) {
  return ref.watch(databaseProvider).shopDao.watchAllShops();
});
