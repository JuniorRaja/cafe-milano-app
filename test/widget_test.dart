import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/providers/order_provider.dart';
import 'package:milano_orders/providers/product_provider.dart';
import 'package:milano_orders/providers/shop_provider.dart';
import 'package:milano_orders/screens/home/home_shops_screen.dart';
import 'package:milano_orders/screens/kitchen/kitchen_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final tomorrow = today.add(const Duration(days: 1));

  // ---------------------------------------------------------------------------
  // Test data helpers
  // ---------------------------------------------------------------------------

  Shop makeShop(int id, String name, {String? area, bool active = true}) =>
      Shop(id: id, name: name, area: area, phone: null, isActive: active);

  DailyOrder makeOrder(int id, int shopId, {bool confirmed = false}) =>
      DailyOrder(id: id, shopId: shopId, orderDate: today, isConfirmed: confirmed);

  OrderDaySummary makeSummary(DailyOrder o, int items, double total) =>
      OrderDaySummary(order: o, itemCount: items, total: total);

  // Builds a test harness: HomeScreen inside a minimal router + ProviderScope
  // with mocked shop and order-summary providers.
  Widget buildApp({
    List<Shop> shops = const [],
    Map<DateTime, List<OrderDaySummary>> summariesByDate = const {},
  }) {
    return ProviderScope(
      overrides: [
        activeShopsProvider.overrideWith(
          (ref) => Stream.value(shops),
        ),
        orderSummariesForDateProvider.overrideWith(
          (ref, date) => Stream.value(summariesByDate[date] ?? []),
        ),
      ],
      child: MaterialApp.router(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF57C00)),
        ),
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeShopsScreen()),
            GoRoute(
              path: '/order/:shopId',
              builder: (_, _) => const Scaffold(body: Text('Order Entry')),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  group('Phase 5 — Home Screen', () {
    testWidgets('shows today\'s date on launch', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(
        find.text(DateFormat('dd MMM yyyy, EEE').format(today)),
        findsOneWidget,
      );
    });

    testWidgets('section header shows active shop count', (tester) async {
      await tester.pumpWidget(buildApp(shops: [
        makeShop(1, 'Hotel Raj', area: 'Anna Nagar'),
        makeShop(2, 'Star Bakery', area: 'T Nagar'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Shops · 2 shops'), findsOneWidget);
    });

    testWidgets('active shops appear as cards with area subtitle', (tester) async {
      await tester.pumpWidget(buildApp(shops: [
        makeShop(1, 'Hotel Raj', area: 'Anna Nagar'),
        makeShop(2, 'Star Bakery', area: 'T Nagar'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Hotel Raj'), findsOneWidget);
      expect(find.text('Star Bakery'), findsOneWidget);
      expect(find.text('Anna Nagar'), findsOneWidget);
      expect(find.text('T Nagar'), findsOneWidget);
    });

    testWidgets('"Tap to add order" shown when shop has no order', (tester) async {
      await tester.pumpWidget(buildApp(shops: [
        makeShop(1, 'Hotel Raj'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Tap to add order'), findsOneWidget);
    });

    testWidgets('pending chip shown for unconfirmed order', (tester) async {
      final o = makeOrder(1, 1);
      await tester.pumpWidget(buildApp(
        shops: [makeShop(1, 'Hotel Raj')],
        summariesByDate: {today: [makeSummary(o, 2, 150.0)]},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Tap to add order'), findsNothing);
    });

    testWidgets('confirmed chip shown for confirmed order', (tester) async {
      final o = makeOrder(1, 1, confirmed: true);
      await tester.pumpWidget(buildApp(
        shops: [makeShop(1, 'Hotel Raj')],
        summariesByDate: {today: [makeSummary(o, 3, 360.0)]},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Pending'), findsNothing);
    });

    testWidgets('item count and rupee total displayed on card', (tester) async {
      final o = makeOrder(1, 1);
      // 2 items, ₹90 total
      await tester.pumpWidget(buildApp(
        shops: [makeShop(1, 'Hotel Raj')],
        summariesByDate: {today: [makeSummary(o, 2, 90.0)]},
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('2 items'), findsOneWidget);
      expect(find.textContaining('₹90'), findsOneWidget);
    });

    testWidgets('confirmed, pending, and no-order states coexist', (tester) async {
      final o1 = makeOrder(1, 1, confirmed: true);
      final o2 = makeOrder(2, 2);
      await tester.pumpWidget(buildApp(
        shops: [
          makeShop(1, 'Hotel Raj'),
          makeShop(2, 'Star Bakery'),
          makeShop(3, 'New Moon Hotel'),
        ],
        summariesByDate: {
          today: [makeSummary(o1, 3, 360.0), makeSummary(o2, 2, 155.0)],
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Tap to add order'), findsOneWidget);
    });

    testWidgets('empty shop list shows 0 count', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Shops · 0 shops'), findsOneWidget);
    });

    testWidgets('< button navigates to previous day', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(
        find.text(DateFormat('dd MMM yyyy, EEE').format(yesterday)),
        findsOneWidget,
      );
    });

    testWidgets('> button navigates to next day', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(
        find.text(DateFormat('dd MMM yyyy, EEE').format(tomorrow)),
        findsOneWidget,
      );
    });

    testWidgets('changing date refreshes order cards reactively', (tester) async {
      final o = makeOrder(1, 1);
      await tester.pumpWidget(buildApp(
        shops: [makeShop(1, 'Hotel Raj')],
        // Order exists only on yesterday, not today
        summariesByDate: {yesterday: [makeSummary(o, 1, 50.0)]},
      ));
      await tester.pumpAndSettle();

      // Today — no order
      expect(find.text('Tap to add order'), findsOneWidget);
      expect(find.text('Pending'), findsNothing);

      // Tap < to go to yesterday
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      // Yesterday — pending chip visible, hint gone
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Tap to add order'), findsNothing);
    });

    testWidgets('tapping a shop card navigates to order entry', (tester) async {
      await tester.pumpWidget(buildApp(shops: [makeShop(1, 'Hotel Raj')]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hotel Raj'));
      await tester.pumpAndSettle();

      expect(find.text('Order Entry'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Phase 8 — Kitchen Screen
  // ---------------------------------------------------------------------------

  group('Phase 8 — Kitchen Screen', () {
    KitchenRawLine makeLine(int shopId, int productId, int qty) =>
        KitchenRawLine(shopId: shopId, productId: productId, qty: qty);

    Product makeProduct(int id, String name, {String? unit}) =>
        Product(id: id, name: name, unit: unit, photoPath: null, isActive: true);

    Widget buildKitchen({
      List<KitchenRawLine> lines = const [],
      List<Shop> shops = const [],
      List<Product> products = const [],
    }) {
      return ProviderScope(
        overrides: [
          kitchenLinesForDateProvider.overrideWith(
            (ref, date) => Stream.value(lines),
          ),
          allShopsProvider.overrideWith((ref) => Stream.value(shops)),
          allProductsProvider.overrideWith((ref) => Stream.value(products)),
        ],
        child: const MaterialApp(home: KitchenScreen()),
      );
    }

    testWidgets('shows today\'s date on launch', (tester) async {
      await tester.pumpWidget(buildKitchen());
      await tester.pumpAndSettle();

      final label = DateFormat('dd MMM yyyy, EEE').format(today);
      expect(find.text(label), findsOneWidget);
    });

    testWidgets('empty state shown when no orders for date', (tester) async {
      await tester.pumpWidget(buildKitchen());
      await tester.pumpAndSettle();

      expect(find.text('No orders for this date'), findsOneWidget);
    });

    testWidgets('share FAB hidden when no orders exist', (tester) async {
      await tester.pumpWidget(buildKitchen());
      await tester.pumpAndSettle();

      expect(find.byTooltip('Share kitchen list'), findsNothing);
    });

    testWidgets('share FAB visible when orders exist', (tester) async {
      await tester.pumpWidget(buildKitchen(
        lines: [makeLine(1, 1, 30)],
        shops: [makeShop(1, 'Hotel Raj')],
        products: [makeProduct(1, 'Bun', unit: 'pc')],
      ));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Share kitchen list'), findsOneWidget);
    });

    testWidgets('By Item tab: products and quantities are displayed', (tester) async {
      await tester.pumpWidget(buildKitchen(
        lines: [makeLine(1, 1, 30), makeLine(1, 2, 10)],
        shops: [makeShop(1, 'Hotel Raj')],
        products: [makeProduct(1, 'Bun'), makeProduct(2, 'Veg Puff')],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Bun'), findsAtLeast(1));
      expect(find.text('Veg Puff'), findsAtLeast(1));
      expect(find.text('30'), findsAtLeast(1));
      expect(find.text('10'), findsAtLeast(1));
    });

    testWidgets('By Item tab: aggregates qty for same product across shops', (tester) async {
      // Shop 1: Bun×30, Shop 2: Bun×20 → total should be 50
      await tester.pumpWidget(buildKitchen(
        lines: [makeLine(1, 1, 30), makeLine(2, 1, 20)],
        shops: [makeShop(1, 'Hotel Raj'), makeShop(2, 'Star Bakery')],
        products: [makeProduct(1, 'Bun')],
      ));
      await tester.pumpAndSettle();

      // Only one Bun row should exist with combined total
      expect(find.text('Bun'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('By Shop tab: shop name header is shown', (tester) async {
      await tester.pumpWidget(buildKitchen(
        lines: [makeLine(1, 1, 30)],
        shops: [makeShop(1, 'Hotel Raj', area: 'Anna Nagar')],
        products: [makeProduct(1, 'Bun')],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('By Shop'));
      await tester.pumpAndSettle();

      // Shop name and area only appear in By Shop tab
      expect(find.text('Hotel Raj'), findsOneWidget);
      expect(find.text('Anna Nagar'), findsOneWidget);
    });

    testWidgets('By Shop tab: per-shop total label shows piece count', (tester) async {
      await tester.pumpWidget(buildKitchen(
        lines: [makeLine(1, 1, 30), makeLine(1, 2, 10)],
        shops: [makeShop(1, 'Hotel Raj')],
        products: [makeProduct(1, 'Bun'), makeProduct(2, 'Veg Puff')],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('By Shop'));
      await tester.pumpAndSettle();

      expect(find.text('40 pcs'), findsOneWidget);
    });

    testWidgets('< button decrements date by one day', (tester) async {
      await tester.pumpWidget(buildKitchen());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      final label = DateFormat('dd MMM yyyy, EEE').format(yesterday);
      expect(find.text(label), findsOneWidget);
    });

    testWidgets('> button increments date by one day', (tester) async {
      await tester.pumpWidget(buildKitchen());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      final label = DateFormat('dd MMM yyyy, EEE').format(tomorrow);
      expect(find.text(label), findsOneWidget);
    });

    testWidgets('switching tabs does not reset the selected date', (tester) async {
      await tester.pumpWidget(buildKitchen());
      await tester.pumpAndSettle();

      // Navigate to yesterday
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      // Switch to By Shop tab
      await tester.tap(find.text('By Shop'));
      await tester.pumpAndSettle();

      // Date selector should still show yesterday
      final label = DateFormat('dd MMM yyyy, EEE').format(yesterday);
      expect(find.text(label), findsOneWidget);
    });
  });
}
