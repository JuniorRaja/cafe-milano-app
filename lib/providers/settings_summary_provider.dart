import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preference key holding when a backup was last exported. Written by
/// `backup_service.dart` on a successful export.
const kLastBackupExportedAt = 'backup_last_exported_at';

/// When the owner last exported a backup, or null if never.
///
/// Its own provider rather than a field on some larger settings object: the
/// Backup tile is the one place it is read, and step 7 of the readiness gate
/// is the reason it is worth surfacing at all.
final lastBackupExportProvider =
    FutureProvider.autoDispose<DateTime?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kLastBackupExportedAt);
  return raw == null ? null : DateTime.tryParse(raw);
});

/// Records an export. Called from the backup service, not from a screen.
Future<void> recordBackupExport(DateTime at) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kLastBackupExportedAt, at.toIso8601String());
}
