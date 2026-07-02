import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'database/seed_data.dart';
import 'providers/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await seedDatabase(container.read(databaseProvider));
  runApp(UncontrolledProviderScope(container: container, child: const MilanoOrdersApp()));
}
