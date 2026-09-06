// Search on the Standing Orders and Price Matrix editors.
//
// The rule these exist to protect: **filtering hides rows and touches nothing
// else.** Both screens hold a `Map<int, TextEditingController>` keyed by
// product id, built once when a shop is picked, and `_save` walks that map
// rather than the visible list. Rebuild the controllers on every keystroke and
// a price typed before a search silently disappears when the search is
// cleared — or worse, is never written. See docs/features/10b-device-pass.md,
// I3.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/providers/database_provider.dart';
import 'package:milano_orders/providers/product_provider.dart';
import 'package:milano_orders/providers/shop_provider.dart';
import 'package:milano_orders/screens/settings/prices/price_matrix_screen.dart';
import 'package:milano_orders/screens/settings/standing_orders/standing_orders_screen.dart';
import 'package:milano_orders/theme/app_theme.dart';
import 'package:milano_orders/theme/brand_config.dart';

void main() {
  late AppDatabase db;
  late int shopId;
  late int bunId;
  late List<Shop> shops;
  late List<Product> products;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    shopId =
        await db.shopDao.upsertShop(ShopsCompanion.insert(name: 'Hotel Raj'));
    bunId = await db.productDao.upsertProduct(
      ProductsCompanion.insert(name: 'Bun', price: const Value(10.0)),
    );
    await db.productDao.upsertProduct(
      ProductsCompanion.insert(name: 'Cake', price: const Value(40.0)),
    );
    shops = await db.shopDao.watchActiveShops().first;
    products = await db.productDao.watchActiveProducts().first;
  });

  tearDown(() => db.close());

  Future<void> io(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // The shop and product lists are read as plain values. Left as the
          // real drift streams they schedule a zero-duration timer when
          // riverpod disposes them, which lands after the widget tree is torn
          // down — "A Timer is still pending even after the widget tree was
          // disposed", and then the whole run hangs. The screens' own reads
          // through `databaseProvider` are what these tests are about, and
          // those stay real.
          activeShopsProvider.overrideWith((ref) => Stream.value(shops)),
          activeProductsProvider.overrideWith((ref) => Stream.value(products)),
        ],
        child: MaterialApp(
          theme: buildAppTheme(BrandConfig.milano),
          home: screen,
        ),
      ),
    );
    await io(tester);

    // Pick the shop, which is what builds the controllers.
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotel Raj').last);
    await tester.pump();
    await io(tester);
  }

  /// The one search box on the screen. The value fields are the other
  /// `TextField`s, so this is found by its hint rather than by position.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Search products'),
      query,
    );
    await tester.pump();
  }

  Finder valueFieldFor(String productName) => find.descendant(
        of: find.ancestor(
          of: find.text(productName),
          matching: find.byType(Row),
        ).first,
        matching: find.byType(TextField),
      );

  group('standing orders', () {
    testWidgets('search hides a row without touching what was typed into it',
        (tester) async {
      await pump(tester, const StandingOrdersScreen());
      expect(find.text('Bun'), findsOneWidget);

      await tester.enterText(valueFieldFor('Bun'), '9');
      await tester.pump();

      await search(tester, 'cake');
      expect(find.text('Bun'), findsNothing);
      expect(find.text('Cake'), findsOneWidget);

      await search(tester, '');
      expect(find.text('Bun'), findsOneWidget);
      expect(
        tester.widget<TextField>(valueFieldFor('Bun')).controller!.text,
        '9',
        reason: 'the controller must survive the row being hidden',
      );
    });

    testWidgets('saving writes the hidden rows too', (tester) async {
      await pump(tester, const StandingOrdersScreen());

      await tester.enterText(valueFieldFor('Bun'), '9');
      await tester.pump();
      await search(tester, 'cake');
      expect(find.text('Bun'), findsNothing);

      await tester.tap(find.textContaining('Save all'));
      await tester.pump();
      await io(tester);

      final saved = await tester.runAsync(
        () => db.priceDao.watchStandingOrdersForShop(shopId).first,
      );
      await tester.pump();
      expect(
        saved!.firstWhere((o) => o.productId == bunId).defaultQty,
        9,
        reason: 'a row filtered off the screen is still an edit',
      );
    });

    testWidgets('the Save button counts every product, not the visible ones',
        (tester) async {
      await pump(tester, const StandingOrdersScreen());
      expect(find.text('Save all 2 products'), findsOneWidget);

      await search(tester, 'cake');
      expect(find.text('Save all 2 products'), findsOneWidget);
    });

    testWidgets('a search matching nothing says so, and says edits are kept',
        (tester) async {
      await pump(tester, const StandingOrdersScreen());
      await search(tester, 'zzz');

      expect(find.text('No product matches'), findsOneWidget);
    });
  });

  group('price matrix', () {
    testWidgets('search hides a row without touching the price typed into it',
        (tester) async {
      await pump(tester, const PriceMatrixScreen());

      await tester.enterText(valueFieldFor('Bun'), '12.50');
      await tester.pump();

      await search(tester, 'cake');
      expect(find.text('Bun'), findsNothing);
      await search(tester, '');

      expect(
        tester.widget<TextField>(valueFieldFor('Bun')).controller!.text,
        '12.50',
      );
    });

    testWidgets('saving writes a price typed before the search',
        (tester) async {
      await pump(tester, const PriceMatrixScreen());

      await tester.enterText(valueFieldFor('Bun'), '12.5');
      await tester.pump();
      await search(tester, 'cake');

      await tester.tap(find.textContaining('Save all'));
      await tester.pump();
      await io(tester);

      final saved = await tester.runAsync(
        () => db.priceDao.watchPricesForShop(shopId).first,
      );
      await tester.pump();
      expect(saved!.firstWhere((p) => p.productId == bunId).price, 12.5);
    });
  });
}
