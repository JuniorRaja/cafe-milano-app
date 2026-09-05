// Back from order entry must return to the tab the shop was opened from.
//
// It did not. `order_entry_screen.dart` called `context.go('/')` on both of
// its back buttons, so leaving a shop jumped to the Overview branch and the
// user lost the Orders tab. Found on the device pass, 2026-09-05. See
// docs/features/10b-device-pass.md, A1.
//
// The two harness rules from `order_entry_flush_test.dart` apply here too:
// drift futures do not advance under the widget-test fake clock, so database
// work goes through `tester.runAsync`; and no `pumpAndSettle`, because the
// loading spinner animates forever and never settles.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:milano_orders/app.dart';
import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/providers/database_provider.dart';
import 'package:milano_orders/screens/order_entry/order_entry_screen.dart';

void main() {
  late AppDatabase db;
  late int shopId;
  late GoRouter router;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    shopId =
        await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Test Shop'));
    await db.productDao.upsertProduct(
      ProductsCompanion.insert(name: 'Bun', price: const Value(10.0)),
    );
  });

  tearDown(() => db.close());

  Future<void> io(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    // Finish the page transition. A route still animating is wrapped in an
    // IgnorePointer, so a tap on the incoming screen goes nowhere and the test
    // fails for a reason that has nothing to do with the back button.
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The three routes this behaviour spans, with the real path constants.
  /// Overview is present precisely so the test can fail if back reaches it.
  Future<void> pump(WidgetTester tester, {required String at}) async {
    router = GoRouter(
      initialLocation: at,
      routes: [
        GoRoute(
          path: AppRoutes.overview,
          builder: (_, _) => const Scaffold(body: Text('OVERVIEW')),
        ),
        GoRoute(
          path: AppRoutes.orders,
          builder: (_, _) => const Scaffold(body: Text('ORDERS')),
        ),
        GoRoute(
          path: AppRoutes.orderEntry,
          builder: (_, state) => OrderEntryScreen(
            shopId: int.parse(state.pathParameters['shopId']!),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await io(tester);
  }

  Future<void> tapBack(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.arrow_back));
    await io(tester);
  }

  testWidgets('back from a pushed order returns to Orders, not the Overview',
      (tester) async {
    await pump(tester, at: AppRoutes.orders);
    expect(find.text('ORDERS'), findsOneWidget);

    router.push(AppRoutes.orderEntryFor(shopId));
    await io(tester);
    expect(find.text('Test Shop'), findsOneWidget,
        reason: 'the order screen should have loaded');

    await tapBack(tester);

    expect(find.text('ORDERS'), findsOneWidget);
    expect(find.text('OVERVIEW'), findsNothing);
  });

  testWidgets('back from a deep link with no stack falls back to Orders',
      (tester) async {
    await pump(tester, at: AppRoutes.orderEntryFor(shopId));
    expect(find.text('Test Shop'), findsOneWidget);

    await tapBack(tester);

    expect(find.text('ORDERS'), findsOneWidget);
    expect(find.text('OVERVIEW'), findsNothing);
  });

  testWidgets('back while the screen is still loading behaves the same',
      (tester) async {
    router = GoRouter(
      initialLocation: AppRoutes.orders,
      routes: [
        GoRoute(
          path: AppRoutes.orders,
          builder: (_, _) => const Scaffold(body: Text('ORDERS')),
        ),
        GoRoute(
          path: AppRoutes.orderEntry,
          builder: (_, state) => OrderEntryScreen(
            shopId: int.parse(state.pathParameters['shopId']!),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await io(tester);

    router.push(AppRoutes.orderEntryFor(shopId));
    // No `runAsync`, so `_init` never completes and the screen stays in its
    // `_loading` branch — which carries the second back button, the one that is
    // easy to forget.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tapBack(tester);
    expect(find.text('ORDERS'), findsOneWidget);
  });
}
