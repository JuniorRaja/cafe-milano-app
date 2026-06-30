import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

final activeProductsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(databaseProvider).productDao.watchActiveProducts();
});
