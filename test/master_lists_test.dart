import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/providers/category_provider.dart';
import 'package:milano_orders/providers/product_provider.dart';
import 'package:milano_orders/providers/shop_provider.dart';
import 'package:milano_orders/screens/settings/categories/category_list_screen.dart';
import 'package:milano_orders/screens/settings/products/product_list_screen.dart';
import 'package:milano_orders/screens/settings/shops/shop_list_screen.dart';
import 'package:milano_orders/theme/app_theme.dart';
import 'package:milano_orders/theme/brand_config.dart';

/// Shops, Products and Categories were three screens doing one job three ways.
/// These assert they now behave as one screen — same header, same search, same
/// counts, same empty states — because "consistent" is a claim that rots
/// silently otherwise.
void main() {
  Shop shop(int id, String name, {String? area, bool active = true}) =>
      Shop(id: id, name: name, area: area, phone: null, isActive: active);

  Product product(
    int id,
    String name, {
    int? categoryId,
    bool active = true,
    String? unit,
    double? price,
  }) =>
      Product(
        id: id,
        name: name,
        unit: unit,
        price: price,
        photoPath: null,
        isActive: active,
        categoryId: categoryId,
      );

  Category category(int id, String name, {bool active = true}) =>
      Category(id: id, name: name, sortOrder: id, isActive: active);

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    List<Shop> shops = const [],
    List<Product> products = const [],
    List<Category> categories = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allShopsProvider.overrideWith((ref) => Stream.value(shops)),
          allProductsProvider.overrideWith((ref) => Stream.value(products)),
          allCategoriesProvider.overrideWith((ref) => Stream.value(categories)),
        ],
        child: MaterialApp.router(
          theme: buildAppTheme(BrandConfig.milano),
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [GoRoute(path: '/', builder: (_, _) => screen)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  group('shops', () {
    testWidgets('searches by name and by area', (tester) async {
      await pump(tester, const ShopListScreen(), shops: [
        shop(1, 'Hotel Raj', area: 'Anna Nagar'),
        shop(2, 'Star Bakery', area: 'T Nagar'),
      ]);

      expect(find.text('Hotel Raj'), findsOneWidget);
      expect(find.text('Star Bakery'), findsOneWidget);

      await search(tester, 'star');
      expect(find.text('Star Bakery'), findsOneWidget);
      expect(find.text('Hotel Raj'), findsNothing);

      // The owner thinks in delivery rounds, not only in shop names.
      await search(tester, 'anna');
      expect(find.text('Hotel Raj'), findsOneWidget);
      expect(find.text('Star Bakery'), findsNothing);
    });

    testWidgets('counts what is there, and flags inactive', (tester) async {
      await pump(tester, const ShopListScreen(), shops: [
        shop(1, 'A'),
        shop(2, 'B'),
        shop(3, 'C', active: false),
      ]);

      expect(find.text('3'), findsWidgets);
      expect(find.text('shops'), findsOneWidget);
      expect(find.text('inactive'), findsOneWidget);
      // Inactive state is a badge, not a tappable chip that toggles on a
      // mis-tap while scrolling.
      expect(find.text('Inactive'), findsOneWidget);
    });

    testWidgets('offers an action when empty, not just sympathy',
        (tester) async {
      await pump(tester, const ShopListScreen());
      expect(find.text('No shops yet'), findsOneWidget);
      expect(find.text('Add your first shop'), findsOneWidget);
    });

    testWidgets('a search matching nothing says so', (tester) async {
      await pump(tester, const ShopListScreen(), shops: [shop(1, 'Hotel Raj')]);
      await search(tester, 'zzz');
      expect(find.text('No shop matches'), findsOneWidget);
    });

    testWidgets('Ledger is on the row, the rest is behind the menu',
        (tester) async {
      await pump(tester, const ShopListScreen(), shops: [shop(1, 'Hotel Raj')]);

      // The footer row is gone; both actions live on the right edge.
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      expect(find.text('Ledger'), findsNothing);
      expect(find.text('Deactivate'), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Deactivate'), findsOneWidget);
    });

    testWidgets('the menu says Activate for a shop that is off',
        (tester) async {
      await pump(
        tester,
        const ShopListScreen(),
        shops: [shop(1, 'Hotel Raj', active: false)],
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Activate'), findsOneWidget);
      expect(find.text('Deactivate'), findsNothing);
    });

    testWidgets('deactivating asks first', (tester) async {
      await pump(tester, const ShopListScreen(), shops: [shop(1, 'Hotel Raj')]);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();

      // Named, so it cannot be confused with the shop below it in the list.
      expect(find.text('Deactivate Hotel Raj?'), findsOneWidget);
    });
  });

  group('products', () {
    testWidgets('searches by name and by category', (tester) async {
      await pump(
        tester,
        const ProductListScreen(),
        categories: [category(1, 'Breads'), category(2, 'Savouries')],
        products: [
          product(1, 'Bun', categoryId: 1),
          product(2, 'Veg Puff', categoryId: 2),
        ],
      );

      await search(tester, 'bun');
      expect(find.text('Bun'), findsOneWidget);
      expect(find.text('Veg Puff'), findsNothing);

      // Typing the category name finds everything in it.
      await search(tester, 'savour');
      expect(find.text('Veg Puff'), findsOneWidget);
      expect(find.text('Bun'), findsNothing);
    });

    testWidgets('the category filter and the search combine', (tester) async {
      await pump(
        tester,
        const ProductListScreen(),
        categories: [category(1, 'Breads')],
        products: [
          product(1, 'Bun', categoryId: 1),
          product(2, 'Brown Bread', categoryId: 1),
          product(3, 'Veg Puff'),
        ],
      );

      // Uncategorised is the last chip.
      await tester.tap(find.text('Uncategorised'));
      await tester.pumpAndSettle();
      expect(find.text('Veg Puff'), findsOneWidget);
      expect(find.text('Bun'), findsNothing);

      await search(tester, 'bun');
      expect(find.text('Nothing in this category'), findsNothing);
      expect(find.text('No product matches'), findsOneWidget);
    });

    testWidgets('the subtitle carries price, unit and category',
        (tester) async {
      await pump(
        tester,
        const ProductListScreen(),
        products: [product(1, 'Veg Puff', categoryId: 1, unit: 'pc', price: 22)],
        categories: [category(1, 'Puffs')],
      );

      expect(find.text('₹22 · pc · 🥟 Puffs'), findsOneWidget);
    });

    testWidgets('a product with no price says so rather than leaving a gap',
        (tester) async {
      // A missing price bills the shop zero. A blank space does not say that.
      await pump(
        tester,
        const ProductListScreen(),
        products: [product(1, 'Veg Puff', unit: 'pc')],
      );

      expect(find.text('Price not set · pc'), findsOneWidget);
    });

    testWidgets('deactivate moved into the menu, and the footer went',
        (tester) async {
      await pump(
        tester,
        const ProductListScreen(),
        products: [product(1, 'Veg Puff')],
      );

      expect(find.text('Deactivate'), findsNothing);
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Deactivate'), findsOneWidget);
    });

    testWidgets('offers an action when empty', (tester) async {
      await pump(tester, const ProductListScreen());
      expect(find.text('No products yet'), findsOneWidget);
      expect(find.text('Add your first product'), findsOneWidget);
    });
  });

  group('categories', () {
    testWidgets('shows how many products are in each', (tester) async {
      // The number that makes a category mean something. The old screen showed
      // an emoji, a name and three buttons, and nothing else.
      await pump(
        tester,
        const CategoryListScreen(),
        categories: [category(1, 'Breads'), category(2, 'Empty')],
        products: [
          product(1, 'Bun', categoryId: 1),
          product(2, 'Brown Bread', categoryId: 1),
        ],
      );

      expect(find.text('2 products'), findsOneWidget);
      expect(find.text('No products yet'), findsOneWidget);
    });

    testWidgets('flags uncategorised products in the counts', (tester) async {
      await pump(
        tester,
        const CategoryListScreen(),
        categories: [category(1, 'Breads')],
        products: [product(1, 'Orphan')],
      );
      expect(find.text('uncategorised'), findsOneWidget);
    });

    testWidgets('searches, and drops reordering while filtered',
        (tester) async {
      // Reordering writes absolute sort positions, so offering it over a
      // filtered subset would write positions the user cannot see.
      await pump(
        tester,
        const CategoryListScreen(),
        categories: [category(1, 'Breads'), category(2, 'Savouries')],
      );
      expect(find.byType(ReorderableListView), findsOneWidget);

      await search(tester, 'bread');
      expect(find.text('Breads'), findsOneWidget);
      expect(find.text('Savouries'), findsNothing);
      expect(find.byType(ReorderableListView), findsNothing);
    });

    testWidgets('inactive reads as a badge, like the other two masters',
        (tester) async {
      await pump(
        tester,
        const CategoryListScreen(),
        categories: [category(1, 'Breads', active: false)],
      );
      expect(find.text('Inactive'), findsOneWidget);
    });
  });

  group('the three masters agree', () {
    testWidgets('each has a caption, a title and a search box', (tester) async {
      for (final screen in const [
        (ShopListScreen(), 'Shops', 'Search shops by name or area'),
        (ProductListScreen(), 'Products', 'Search products by name or category'),
        (CategoryListScreen(), 'Categories', 'Search categories'),
      ]) {
        await pump(tester, screen.$1);
        // AppScaffold renders the caption uppercase.
        expect(find.text('CATALOGUE'), findsOneWidget,
            reason: '${screen.$2} is missing the shared caption');
        expect(find.text(screen.$2), findsOneWidget);
        expect(find.text(screen.$3), findsOneWidget,
            reason: '${screen.$2} is missing its search box');
      }
    });
  });
}
