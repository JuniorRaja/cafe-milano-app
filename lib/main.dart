import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/error_reporting.dart';

/// `runApp` first, then the work.
///
/// This function used to build a `ProviderContainer` by hand, read the
/// database out of it, and seed before calling `runApp`. That cost two things.
/// The container was never owned by a `ProviderScope`, so `databaseProvider`'s
/// `ref.onDispose(db.close)` could never fire and the SQLite handle was
/// released only by process death. And any throw before `runApp` produced a
/// native splash that never resolved.
///
/// Bootstrap now runs inside the tree — see `bootstrap_provider.dart`.
void main() {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  installErrorHandlers();

  runApp(
    const ProviderScope(
      observers: [AppProviderObserver()],
      child: OrdersApp(),
    ),
  );
}
