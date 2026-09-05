// The search box, the category filter and the overflow menu on order entry.
//
// The rule these exist to protect: **filtering changes what is drawn and
// nothing else.** `_qtys` is keyed by product id and `_save` walks `_products`,
// not the visible list, so a row filtered off the screen keeps its quantity and
// still gets written. Get that wrong and the owner loses an order by typing in
// a search box. See docs/features/10b-device-pass.md, E2 and E7.
//
// Harness rules carried over from `order_entry_flush_test.dart`: drift futures
// do not advance under the widget-test fake clock, so database work goes
// through `tester.runAsync`; and no `pumpAndSettle`, because the loading
// spinner animates forever.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/providers/database_provider.dart';
import 'package:milano_orders/screens/order_entry/order_entry_screen.dart';

void main() {
  late AppDatabase db;
  late int shopId;
  late int bunId;
  late int cakeId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    shopId =
        await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Test Shop'));
    final bakery = await db.categoryDao.insertCategory('Bread', 0);
    final sweets = await db.categoryDao.insertCategory('Cakes', 1);
    bunId = await db.productDao.upsertProduct(
      ProductsCompanion.insert(
        name: 'Bun',
        price: const Value(10.0),
        categoryId: Value(bakery),
      ),
    );
    cakeId = await db.productDao.upsertProduct(
      ProductsCompanion.insert(
        name: 'Cake',
        price: const Value(40.0),
        categoryId: Value(sweets),
      ),
    );
  });

  tearDown(() => db.close());

  Future<void> io(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }

  Future<List<OrderLine>> lines(WidgetTester tester) async {
    final rows = await tester.runAsync(() => db.select(db.orderLines).get());
    await tester.pump();
    return rows!;
  }

  Future<void> pumpOrderEntry(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: OrderEntryScreen(shopId: shopId)),
      ),
    );
    await io(tester);
    expect(find.text('Bun'), findsOneWidget);
    expect(find.text('Cake'), findsOneWidget);
  }

  /// Types into the one search field on the screen.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pump();
  }

  testWidgets('search hides rows without touching their quantities',
      (tester) async {
    await pumpOrderEntry(tester);

    // One on the Bun. `.first` is Bun's stepper — the list is alphabetical.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();

    await search(tester, 'cake');
    expect(find.text('Bun'), findsNothing, reason: 'Bun should be filtered out');
    expect(find.text('Cake'), findsOneWidget);

    // The debounce fires while Bun is off screen.
    await tester.pump(const Duration(milliseconds: 600));
    await io(tester);

    final saved = await lines(tester);
    final bun = saved.firstWhere((l) => l.productId == bunId);
    expect(bun.qty, 1,
        reason: 'a hidden row must keep its quantity and still be saved');
  });

  testWidgets('the header count says what is on screen while filtering',
      (tester) async {
    await pumpOrderEntry(tester);
    expect(find.text('2 items'), findsOneWidget);

    await search(tester, 'cake');
    expect(find.text('1 of 2'), findsOneWidget,
        reason: 'the count must not claim 2 over a list of one');
  });

  testWidgets('clearing the search brings the row back with its quantity',
      (tester) async {
    await pumpOrderEntry(tester);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    await search(tester, 'cake');
    await search(tester, '');

    expect(find.text('Bun'), findsOneWidget);
    // The quantity column still reads 1, so nothing was reset on the way back.
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('the category filter narrows the list', (tester) async {
    await pumpOrderEntry(tester);
    // The screen only reaches `categoriesProvider` on the build *after*
    // `_init` finishes — the loading branch returns before it. So the read is
    // still in flight here, and like every other drift future in these tests it
    // needs a real turn of the event loop before the sheet can list anything.
    await io(tester);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🍰 Cakes'));
    await tester.pumpAndSettle();

    expect(find.text('Cake'), findsOneWidget);
    expect(find.text('Bun'), findsNothing);
  });

  testWidgets('Clear all quantities sets every row to zero, hidden ones too',
      (tester) async {
    await pumpOrderEntry(tester);

    await tester.tap(find.byIcon(Icons.add).first); // Bun
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add).last); // Cake
    await tester.pump();

    // Filter Bun away first: clearing must reach the rows it cannot see, for
    // the same reason saving does.
    await search(tester, 'cake');

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all quantities'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear')); // the confirm dialog
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 600));
    await io(tester);

    final saved = await lines(tester);
    expect(saved.where((l) => l.qty != 0), isEmpty,
        reason: 'every quantity should be zero, visible or not');
  });

  testWidgets('the menu names the standing order, or says there is none',
      (tester) async {
    await pumpOrderEntry(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('No standing order set'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // dismiss
    await tester.pumpAndSettle();
  });

  testWidgets('with a standing order the card and the menu both name its size',
      (tester) async {
    await db.priceDao.upsertStandingOrder(StandingOrdersCompanion(
      shopId: Value(shopId),
      productId: Value(bunId),
      defaultQty: const Value(9),
    ));
    await db.priceDao.upsertStandingOrder(StandingOrdersCompanion(
      shopId: Value(shopId),
      productId: Value(cakeId),
      defaultQty: const Value(3),
    ));

    await pumpOrderEntry(tester);

    // The info card, where "Order Type: Regular Order" used to be.
    expect(find.text('Standing Order'), findsOneWidget);
    expect(find.text('12 items'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Load standing order (12 items)'), findsOneWidget);
  });
}
