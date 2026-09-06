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
    testWidgets('standing orders and dashboard sections count what is set',
        (tester) async {
      await pump(
        tester,
        coverage: const CatalogueCoverage(
          pricesSet: 212,
          priceSlots: 504,
          shopsWithStandingOrders: 7,
        ),
      );

      expect(find.text('7 shops have default quantities'), findsOneWidget);
      expect(find.textContaining('sections visible'), findsOneWidget);
    });

    testWidgets('an unconfigured app says so rather than showing 0 of 0',
        (tester) async {
      await pump(tester);
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

    testWidgets('the installed version is shown without a check',
        (tester) async {
      await pump(tester);
      expect(find.text('Installed v1.11.0 (build 15)'), findsOneWidget);
    });

    testWidgets('the masters are listed here, as a Catalogue card',
        (tester) async {
      // They were taken out of Settings in 10b and put back on the device
      // pass. See docs/features/10b-device-pass.md, J4.
      await pump(tester, shops: [shop(1, 'Hotel Raj')]);

      expect(find.text('Catalogue'), findsOneWidget);
      expect(find.text('Shops'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Price Matrix'), findsOneWidget);
      expect(find.text('Configuration'), findsOneWidget);
    });

    testWidgets('each catalogue row reports its own state', (tester) async {
      await pump(
        tester,
        shops: [shop(1, 'Hotel Raj'), shop(2, 'Closed Down', active: false)],
        products: [product(1, 'Bun')],
        categories: [category(1, 'Bread')],
        coverage: const CatalogueCoverage(
          pricesSet: 212,
          priceSlots: 504,
          shopsWithStandingOrders: 3,
        ),
      );

      expect(find.text('1 active · 1 inactive'), findsOneWidget);
      // Products and Categories both read `1 active`.
      expect(find.text('1 active'), findsNWidgets(2));
      expect(find.text('212 of 504 prices set'), findsOneWidget);
    });

    testWidgets('an empty master says so rather than showing a zero',
        (tester) async {
      await pump(tester);
      expect(find.text('None yet'), findsNWidgets(3));
      expect(find.text('No shops or products yet'), findsOneWidget);
    });

    testWidgets('a master is not offered twice by the search', (tester) async {
      // The Screens section already lists every destination. Repeating them as
      // Settings rows would return Shops twice for one query.
      await pump(tester, shops: [shop(1, 'Hotel Raj')]);

      await tester.enterText(find.byType(TextField), 'shops');
      await tester.pumpAndSettle();
      expect(find.text('Shops'), findsOneWidget);
    });
  });

  group('search reaches the whole app', () {
    testWidgets('one keystroke finds a screen that is not in Settings',
        (tester) async {
      await pump(tester);

      // Kitchen is a bottom-bar destination and has no settings row. Before
      // 10b nothing on this screen could reach it. The masters are the same
      // case now that they have left Settings for the drawer.
      await tester.enterText(find.byType(TextField), 'kitchen');
      await tester.pumpAndSettle();

      expect(find.text('Screens'), findsOneWidget);
      expect(find.text('Kitchen'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'shops');
      await tester.pumpAndSettle();
      expect(find.text('Shops'), findsOneWidget);
    });

    testWidgets('a destination is found by what the owner would type',
        (tester) async {
      await pump(tester);

      // "receivables" is a keyword on Ledger, not its label.
      await tester.enterText(find.byType(TextField), 'receivables');
      await tester.pumpAndSettle();
      expect(find.text('Ledger'), findsOneWidget);
    });

    testWidgets('the old name still finds the renamed screen', (tester) async {
      await pump(tester);

      // Finances became Ledger. `finances` stayed a keyword, so the owner's
      // muscle memory and every note they wrote still land on it.
      await tester.enterText(find.byType(TextField), 'finances');
      await tester.pumpAndSettle();
      expect(find.text('Ledger'), findsOneWidget);
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
      expect(find.text('Configuration'), findsNothing);

      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Configuration'), findsOneWidget);
    });
  });
}
