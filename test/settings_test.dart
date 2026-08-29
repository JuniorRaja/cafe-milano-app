import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/providers/business_info_provider.dart';
import 'package:milano_orders/providers/category_provider.dart';
import 'package:milano_orders/providers/price_provider.dart';
import 'package:milano_orders/providers/product_provider.dart';
import 'package:milano_orders/providers/settings_summary_provider.dart';
import 'package:milano_orders/providers/shop_provider.dart';
import 'package:milano_orders/screens/settings/settings_screen.dart';
import 'package:milano_orders/theme/app_theme.dart';
import 'package:milano_orders/theme/brand_config.dart';

/// Settings after doc 10b: every tile reports state rather than prose, and the
/// search field reaches the whole app rather than this screen.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Milano Orders',
      packageName: 'com.example.milano',
      version: '1.11.0',
      buildNumber: '15',
      buildSignature: '',
    );
  });

  Shop shop(int id, String name, {bool active = true}) =>
      Shop(id: id, name: name, area: null, phone: null, isActive: active);

  Product product(int id, String name, {bool active = true}) => Product(
        id: id,
        name: name,
        unit: null,
        photoPath: null,
        isActive: active,
      );

  Category category(int id, String name) =>
      Category(id: id, name: name, sortOrder: 0, isActive: true);

  Future<void> pump(
    WidgetTester tester, {
    List<Shop> shops = const [],
    List<Product> products = const [],
    List<Category> categories = const [],
    CatalogueCoverage coverage = CatalogueCoverage.empty,
    DateTime? lastExport,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allShopsProvider.overrideWith((ref) => Stream.value(shops)),
          allProductsProvider.overrideWith((ref) => Stream.value(products)),
          allCategoriesProvider.overrideWith((ref) => Stream.value(categories)),
          catalogueCoverageProvider.overrideWith(
            (ref) => Stream.value(coverage),
          ),
          businessInfoProvider.overrideWith((ref) => Stream.value(null)),
          lastBackupExportProvider.overrideWith((ref) async => lastExport),
        ],
        child: MaterialApp.router(
          theme: buildAppTheme(BrandConfig.milano),
          routerConfig: GoRouter(
            initialLocation: '/settings',
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('tiles report state, not prose', () {
    testWidgets('shops, categories and products count what exists',
        (tester) async {
      await pump(
        tester,
        shops: [
          shop(1, 'Hotel Raj'),
          shop(2, 'Star Bakery'),
          shop(3, 'Closed Down', active: false),
        ],
        products: [product(1, 'Bun'), product(2, 'Veg Puff')],
        categories: [category(1, 'Breads'), category(2, 'Savouries')],
      );

      expect(find.text('2 active · 1 inactive'), findsOneWidget);
      expect(find.text('2 categories'), findsOneWidget);
      expect(find.text('2 active in 2 categories'), findsOneWidget);
    });

    testWidgets('price coverage reads as coverage, not as missing rows',
        (tester) async {
      await pump(
        tester,
        coverage: const CatalogueCoverage(
          pricesSet: 212,
          priceSlots: 504,
          shopsWithStandingOrders: 7,
        ),
      );

      expect(find.text('212 of 504 per-shop prices set'), findsOneWidget);
      expect(find.text('7 shops have default quantities'), findsOneWidget);
    });

    testWidgets('an empty catalogue says so rather than showing 0 of 0',
        (tester) async {
      await pump(tester);

      expect(find.text('No shops yet'), findsOneWidget);
      expect(find.text('No products yet'), findsOneWidget);
      expect(find.text('Add shops and products first'), findsOneWidget);
      expect(find.text('No default quantities set'), findsOneWidget);
    });

    testWidgets('backup reports when data was last saved', (tester) async {
      await pump(tester, lastExport: DateTime.now());
      expect(find.text('Last exported today'), findsOneWidget);
    });

    testWidgets('never having exported is called out', (tester) async {
      // Step 7 of the readiness gate is the one that gets skipped and the one
      // that corrupts real data. Saying "Never exported" is the cheapest
      // possible nudge.
      await pump(tester);
      expect(find.text('Never exported'), findsOneWidget);
    });

    testWidgets('the installed version is shown without a check', (tester) async {
      await pump(tester);
      expect(find.text('Installed v1.11.0 (build 15)'), findsOneWidget);
    });
  });

  group('search reaches the whole app', () {
    testWidgets('one keystroke finds a screen that is not in Settings',
        (tester) async {
      await pump(tester);

      // Kitchen is a bottom-bar destination and has no settings row. Before
      // 10b nothing on this screen could reach it.
      await tester.enterText(find.byType(TextField), 'kitchen');
      await tester.pumpAndSettle();

      expect(find.text('Screens'), findsOneWidget);
      expect(find.text('Kitchen'), findsOneWidget);
    });

    testWidgets('a destination is found by what the owner would type',
        (tester) async {
      await pump(tester);

      // "receivables" is a keyword on Outstanding, not its label.
      await tester.enterText(find.byType(TextField), 'receivables');
      await tester.pumpAndSettle();
      expect(find.text('Outstanding'), findsOneWidget);
    });

    testWidgets('a settings row is found by keyword too', (tester) async {
      await pump(tester);

      // "restore" is a keyword on Backup & Restore.
      await tester.enterText(find.byType(TextField), 'restore');
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Backup & Restore'), findsOneWidget);
    });

    testWidgets('an unshipped destination is never a search result',
        (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'suggestions');
      await tester.pumpAndSettle();
      expect(find.text('Auto Suggestions'), findsNothing);
      expect(find.text('Nothing matches'), findsOneWidget);
    });

    testWidgets('clearing the search restores the full screen', (tester) async {
      await pump(tester, shops: [shop(1, 'Hotel Raj')]);

      await tester.enterText(find.byType(TextField), 'kitchen');
      await tester.pumpAndSettle();
      expect(find.text('Catalogue'), findsNothing);

      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Catalogue'), findsOneWidget);
      expect(find.text('Configuration'), findsOneWidget);
    });
  });
}
