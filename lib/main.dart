import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'database/dev_seed.dart';
import 'database/seed_data.dart';
import 'providers/database_provider.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  final container = ProviderContainer();
  final db = container.read(databaseProvider);
  if (kDebugMode) {
    await seedFromBackup(db);
  } else {
    await seedDatabase(db);
  }
  runApp(UncontrolledProviderScope(container: container, child: const MilanoOrdersApp()));
  FlutterNativeSplash.remove();
}
