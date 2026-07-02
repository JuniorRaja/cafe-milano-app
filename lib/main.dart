import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'database/seed_data.dart';
import 'providers/database_provider.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  final container = ProviderContainer();
  await seedDatabase(container.read(databaseProvider));
  runApp(UncontrolledProviderScope(container: container, child: const MilanoOrdersApp()));
  FlutterNativeSplash.remove();
}
