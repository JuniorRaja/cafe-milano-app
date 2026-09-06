import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show compute;
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/app_database.dart';
import '../theme/brand_config.dart';
import '../providers/settings_summary_provider.dart';

const _backupFilePrefix = 'cafe-milano-backup-';

/// Base64-encodes the photo bytes and JSON-encode run off the main isolate via [compute].
String _buildBackupJson(Map<String, dynamic> args) {
  final imageBytes = args['imageBytes'] as Map<String, List<int>>;
  final images = {
    for (final entry in imageBytes.entries) entry.key: base64Encode(entry.value),
  };
  final backup = {
    'appVersion': args['appVersion'],
    'schemaVersion': args['schemaVersion'],
    'exportedAt': args['exportedAt'],
    ...(args['data'] as Map<String, dynamic>),
    'images': images,
  };
  return jsonEncode(backup);
}

/// Builds a full backup (all tables + referenced product/logo photos, embedded
/// as base64) and opens the OS share sheet so the user can save it wherever
/// they like off-device.
Future<void> exportAndShareBackup(AppDatabase db) async {
  final data = await db.backupDao.exportAll();
  final imageBytes = <String, List<int>>{};

  final products = data['products'] as List<dynamic>;
  for (final productJson in products) {
    final photoPath = productJson['photoPath'] as String?;
    if (photoPath == null) continue;
    final file = File(photoPath);
    if (!await file.exists()) continue;
    try {
      final bytes = await file.readAsBytes();
      final ext = p.extension(photoPath);
      imageBytes['product_${productJson['id']}$ext'] = bytes;
    } catch (_) {
      // Skip products whose photo file no longer exists on disk.
    }
  }

  final businessInfoJson = data['businessInfo'] as Map<String, dynamic>?;
  final logoPath = businessInfoJson?['logoPath'] as String?;
  if (logoPath != null) {
    final file = File(logoPath);
    if (await file.exists()) {
      try {
        final bytes = await file.readAsBytes();
        final ext = p.extension(logoPath);
        imageBytes['logo$ext'] = bytes;
      } catch (_) {
        // Skip if the logo file no longer exists on disk.
      }
    }
  }

  final packageInfo = await PackageInfo.fromPlatform();
  final jsonString = await compute(_buildBackupJson, {
    'appVersion': packageInfo.version,
    'schemaVersion': db.schemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'data': data,
    'imageBytes': imageBytes,
  });

  final dir = await getTemporaryDirectory();
  // Sweep prior exports
  for (final entry in dir.listSync()) {
    final name = p.basename(entry.path);
    if (entry is File && name.startsWith(_backupFilePrefix) && name.endsWith('.json')) {
      try {
        await entry.delete();
      } catch (_) {
        // Best-effort cleanup; a locked file shouldn't block the new export.
      }
    }
  }

  final timestamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
  final file = File(p.join(dir.path, '$_backupFilePrefix$timestamp.json'));
  await file.writeAsString(jsonString);

  await recordBackupExport(DateTime.now());

  await Share.shareXFiles([XFile(file.path)], text: '${BrandConfig.milano.appName} Backup');
}

/// Thrown when a file picked for import isn't a valid/compatible backup.
class InvalidBackupException implements Exception {
  InvalidBackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

String? _findImageKey(Map<String, dynamic> images, String prefix) {
  for (final key in images.keys) {
    if (key.startsWith(prefix)) return key;
  }
  return null;
}

/// Wipes all local data and replaces it with the contents of [file].
Future<void> importBackup(AppDatabase db, File file) async {
  final Map<String, dynamic> backup;
  try {
    backup = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    throw InvalidBackupException('This file is not a valid backup.');
  }

  // payments / paymentAllocations are intentionally not required: backups from
  // pre-ledger builds (schema < 6) don't carry them, and restoreAll reads both
  // as `as List? ?? []`.
  const requiredKeys = [
    'schemaVersion',
    'categories',
    'shops',
    'products',
    'shopPrices',
    'standingOrders',
    'dailyOrders',
    'orderLines',
  ];
  if (requiredKeys.any((key) => !backup.containsKey(key))) {
    throw InvalidBackupException(
        'This file is not a valid ${BrandConfig.milano.appName} backup.');
  }
  // ponytail: accepts any older schema because every migration to date is purely
  // additive (new tables / nullable columns). A future migration that adds a
  // NOT NULL column, renames, or transforms data needs a per-version coercion
  // block here keyed off backup['schemaVersion'].
  if ((backup['schemaVersion'] as num) > db.schemaVersion) {
    throw InvalidBackupException(
      'This backup is from a newer app version. Update the app, then restore.',
    );
  }

  final images = Map<String, dynamic>.from(backup['images'] as Map? ?? {});
  final imagesDir = Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'imported_photos'),
  );
  await imagesDir.create(recursive: true);

  final products = (backup['products'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  for (final product in products) {
    final imageKey = _findImageKey(images, 'product_${product['id']}.');
    if (imageKey == null) {
      product['photoPath'] = null;
      continue;
    }
    final bytes = base64Decode(images[imageKey] as String);
    final outFile = File(p.join(imagesDir.path, imageKey));
    await outFile.writeAsBytes(bytes);
    product['photoPath'] = outFile.path;
  }

  Map<String, dynamic>? businessInfoJson;
  if (backup['businessInfo'] != null) {
    businessInfoJson = Map<String, dynamic>.from(backup['businessInfo'] as Map);
    final logoKey = _findImageKey(images, 'logo.');
    if (logoKey != null) {
      final bytes = base64Decode(images[logoKey] as String);
      final outFile = File(p.join(imagesDir.path, logoKey));
      await outFile.writeAsBytes(bytes);
      businessInfoJson['logoPath'] = outFile.path;
    } else {
      businessInfoJson['logoPath'] = null;
    }
  }

  await db.backupDao.restoreAll({
    'categories': backup['categories'],
    'shops': backup['shops'],
    'products': products,
    'businessInfo': businessInfoJson,
    'shopPrices': backup['shopPrices'],
    'standingOrders': backup['standingOrders'],
    'dailyOrders': backup['dailyOrders'],
    'orderLines': backup['orderLines'],
    'payments': backup['payments'],
    'paymentAllocations': backup['paymentAllocations'],
  });
}
