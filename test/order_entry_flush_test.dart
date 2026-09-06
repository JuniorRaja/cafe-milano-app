// The order-entry save is debounced by 500 ms. Leaving the screen inside that
// window used to throw the pending save away — every quantity typed in the last
// half-second before a pop was silently lost. See docs/features/18.
//
// Two harness rules this file depends on:
//  * Drift futures do not advance under the widget-test fake clock, so every
//    database call goes through `tester.runAsync`.
//  * No `pumpAndSettle`: while `_loading` is true the screen shows a
//    CircularProgressIndicator, which animates forever and never settles.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  // Lets the real event loop run so pending drift work completes, then rebuilds.
  Future<void> io(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }

  // Reads the saved lines, then drains the zero-duration timers drift leaves
  // behind — otherwise the binding asserts on them when the test ends.
  Future<List<OrderLine>> lines(WidgetTester tester) async {
    final rows = await tester.runAsync(() => db.select(db.orderLines).get());
    await tester.pump();
    return rows!;
  }

  Future<void> pumpOrderEntry(WidgetTester tester) async {
    router = GoRouter(
      initialLocation: '/order/$shopId',
      routes: [
        GoRoute(
            path: '/', builder: (_, _) => const Scaffold(body: Text('Home'))),
        GoRoute(
          path: '/order/:shopId',
          builder: (_, state) => OrderEntryScreen(
            shopId: int.parse(state.pathParameters['shopId']!),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await io(tester); // _init: shop, order, products, prices
    expect(find.byIcon(Icons.add), findsWidgets,
        reason: 'the screen should have finished loading');
  }

  testWidgets(
      'a quantity entered 100 ms before leaving still reaches the database',
      (tester) async {
    await pumpOrderEntry(tester);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    // Well inside the 500 ms debounce window — nothing written yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(await lines(tester), isEmpty,
        reason: 'the debounce should not have fired yet');

    // Tear the screen down. Navigating instead would need ~300 ms of fake clock
    // for the route transition, which is enough for the 500 ms debounce to fire
    // on its own — the test would then pass without the flush existing at all.
    await tester.pumpWidget(const SizedBox());
    await io(tester);

    final saved = await lines(tester);
    expect(saved.length, 1);
    expect(saved.first.qty, 1);
  });
}
