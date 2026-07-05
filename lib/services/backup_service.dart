import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/app_database.dart';

/// Builds a full backup (all tables + referenced product/logo photos, embedded
/// as base64) and opens the OS share sheet so the user can save it wherever
/// they like off-device.
Future<void> exportAndShareBackup(AppDatabase db) async {
  final data = await db.backupDao.exportAll();
  final images = <String, String>{};

  final products = data['products'] as List<dynamic>;
  for (final productJson in products) {
    final photoPath = productJson['photoPath'] as String?;
    if (photoPath == null) continue;
    final file = File(photoPath);
    if (!await file.exists()) continue;
    try {
      final bytes = await file.readAsBytes();
      final ext = p.extension(photoPath);
      images['product_${productJson['id']}$ext'] = base64Encode(bytes);
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
        images['logo$ext'] = base64Encode(bytes);
      } catch (_) {
        // Skip if the logo file no longer exists on disk.
      }
    }
  }

  final packageInfo = await PackageInfo.fromPlatform();
  final backup = {
    'appVersion': packageInfo.version,
    'schemaVersion': db.schemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    ...data,
    'images': images,
  };

  final dir = await getTemporaryDirectory();
  final timestamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
  final file = File(p.join(dir.path, 'cafe-milano-backup-$timestamp.json'));
  await file.writeAsString(jsonEncode(backup));

  await Share.shareXFiles([XFile(file.path)], text: 'Cafe Milano Backup');
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

  const requiredKeys = [
    'schemaVersion',
    'shops',
    'products',
    'shopPrices',
    'standingOrders',
    'dailyOrders',
    'orderLines',
  ];
  if (requiredKeys.any((key) => !backup.containsKey(key))) {
    throw InvalidBackupException('This file is not a valid Cafe Milano backup.');
  }
  if (backup['schemaVersion'] != db.schemaVersion) {
    throw InvalidBackupException(
      'This backup is from an incompatible app version and cannot be restored here.',
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
    'shops': backup['shops'],
    'products': products,
    'businessInfo': businessInfoJson,
    'shopPrices': backup['shopPrices'],
    'standingOrders': backup['standingOrders'],
    'dailyOrders': backup['dailyOrders'],
    'orderLines': backup['orderLines'],
  });
}
