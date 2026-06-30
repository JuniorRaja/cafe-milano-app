import 'package:cafe_milano/database/app_database.dart';
import 'package:cafe_milano/providers/order_provider.dart';
import 'package:cafe_milano/providers/shop_provider.dart';
import 'package:cafe_milano/screens/home/home_screen.dart';
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
            GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
            GoRoute(
              path: '/order/:shopId',
              builder: (_, __) => const Scaffold(body: Text('Order Entry')),
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
}
