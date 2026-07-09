import 'dart:convert';
import 'package:flutter/services.dart';
import 'app_database.dart';
import 'seed_data.dart';

const _backupAsset = 'docs/cafe-milano-backup-20260708-224812.json';

Future<void> seedFromBackup(AppDatabase db) async {
  final existing = await db.select(db.shops).get();
  if (existing.isNotEmpty) return;

  final raw = await rootBundle.loadString(_backupAsset);
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
