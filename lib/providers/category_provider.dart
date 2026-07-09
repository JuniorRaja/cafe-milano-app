import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

final activeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(databaseProvider).categoryDao.watchActive();
});

final allCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(databaseProvider).categoryDao.watchAll();
});
