import 'dart:convert';
import 'dart:io';
import 'app_database.dart';
import 'seed_data.dart';

const _seedPath = 'dev/seed.json';

Future<void> seedFromBackup(AppDatabase db) async {
  final file = File(_seedPath);
  if (!file.existsSync()) return;

  final existing = await db.select(db.shops).get();
  if (existing.isNotEmpty) return;

  final raw = await file.readAsString();
  final backup = jsonDecode(raw) as Map<String, dynamic>;

  await db.backupDao.restoreAll({
    'categories': backup['categories'] ?? <dynamic>[],
    'shops': backup['shops'],
    'products': backup['products'],
    'businessInfo': backup['businessInfo'],
    'shopPrices': backup['shopPrices'],
    'standingOrders': backup['standingOrders'],
    'dailyOrders': backup['dailyOrders'],
    'orderLines': backup['orderLines'],
  });

  // Backup may be from a pre-category version; ensure defaults are present.
  await seedDefaultCategories(db);
}
