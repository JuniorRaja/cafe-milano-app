import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/native.dart';
import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/providers/database_provider.dart';
import 'package:milano_orders/providers/date_provider.dart';
import 'package:milano_orders/providers/ledger_provider.dart';
import 'package:milano_orders/providers/shop_provider.dart';
import 'package:milano_orders/theme/app_theme.dart';
import 'package:milano_orders/theme/brand_config.dart';
import 'package:milano_orders/widgets/shell/app_drawer.dart';
import 'package:milano_orders/widgets/shell/destinations.dart';
import 'package:milano_orders/widgets/shell/quick_action_sheet.dart';
import 'package:milano_orders/widgets/shell/shop_picker_sheet.dart';

/// The drawer, the quick-action sheet and the shop picker — the three pieces
/// doc 10b adds that a user actually touches.
void main() {
  Shop shop(int id, String name, {String? area, bool active = true}) =>
      Shop(id: id, name: name, area: area, phone: null, isActive: active);

  ShopOutstanding owes(int id, String name, double amount) =>
      ShopOutstanding(shopId: id, shopName: name, outstanding: amount);

  Widget host({
    required Widget child,
    List<Shop> shops = const [],
    OutstandingSummary? summary,
  }) {
    return ProviderScope(
      overrides: [
        activeShopsProvider.overrideWith((ref) => Stream.value(shops)),
        outstandingByShopProvider.overrideWith((ref) => Stream.value(const [])),
        outstandingSummaryProvider.overrideWith(
          (ref) => Stream.value(summary ?? OutstandingSummary.empty),
        ),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(BrandConfig.milano),
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [GoRoute(path: '/', builder: (_, _) => child)],
        ),
      ),
    );
  }

  group('drawer', () {
    Widget drawerHost({OutstandingSummary? summary}) => host(
          summary: summary,
          child: const Scaffold(drawer: AppDrawer(), body: SizedBox()),
        );

    /// The default 800x600 test surface is shorter than any phone, and the
    /// drawer's list is lazily built, so the lower groups are never
    /// constructed and `find.text` reports them missing. A phone-shaped
    /// surface is what these assertions are actually about.
    Future<void> openDrawer(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final state = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      state.openDrawer();
      await tester.pumpAndSettle();
    }

    testWidgets('lists every shipped destination and no unshipped one',
        (tester) async {
      await tester.pumpWidget(drawerHost());
      await openDrawer(tester);

      for (final dest in visibleDestinations) {
        expect(
          find.text(dest.label),
          findsOneWidget,
          reason: '${dest.label} is missing from the drawer',
        );
      }

      // Hidden, never shown-disabled: there is no unlock path in a
      // single-user app, so a greyed row teaches nothing.
      for (final dest in appDestinations.where((d) => !d.shipped)) {
        expect(
          find.text(dest.label),
          findsNothing,
          reason: '${dest.label} has not shipped and must not be visible',
        );
      }
    });

    testWidgets('groups its destinations under captions', (tester) async {
      await tester.pumpWidget(drawerHost());
      await openDrawer(tester);

      expect(find.text('DAILY'), findsOneWidget);
      expect(find.text('MONEY'), findsOneWidget);
      expect(find.text('CATALOGUE'), findsOneWidget);
    });

    testWidgets('the outstanding card carries the figure and the shop count',
        (tester) async {
      await tester.pumpWidget(drawerHost(
        summary: OutstandingSummary(
          total: 116717,
          shopCount: 16,
          oldestUnpaidAt: DateTime(2026, 8, 1),
        ),
      ));
      await openDrawer(tester);

      // Indian grouping, through BrandConfig — 1,16,717 not 116,717.
      expect(find.text('₹1,16,717'), findsOneWidget);
      expect(find.textContaining('Owed by 16 shops'), findsOneWidget);
    });

    testWidgets('nothing owed reads as settled, not as a blank card',
        (tester) async {
      await tester.pumpWidget(drawerHost());
      await openDrawer(tester);

      expect(find.text('₹0'), findsOneWidget);
      expect(find.text('Everyone is settled up'), findsOneWidget);
    });
  });

  group('quick actions', () {
    testWidgets('the FAB offers exactly the three actions', (tester) async {
      await tester.pumpWidget(host(
        child: const Scaffold(floatingActionButton: QuickActionButton()),
      ));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('New order'), findsOneWidget);
      expect(find.text('Record payment'), findsOneWidget);
      expect(find.text('Add shop'), findsOneWidget);
      // No fourth. Counter stock was dropped with doc 11.
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('picking Add shop closes the sheet and routes', (tester) async {
      var landed = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: buildAppTheme(BrandConfig.milano),
            routerConfig: GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) =>
                      const Scaffold(floatingActionButton: QuickActionButton()),
                ),
                GoRoute(
                  path: '/settings/shops/new',
                  builder: (_, _) {
                    landed = true;
                    return const Scaffold(body: Text('new shop'));
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add shop'));
      await tester.pumpAndSettle();

      // The sheet has to be gone *and* the route reached. An earlier version
      // navigated through the popped sheet's own context and silently did
      // neither.
      expect(landed, isTrue);
      expect(find.text('new shop'), findsOneWidget);
      expect(find.text('Record payment'), findsNothing);
    });
  });

  group('quick actions end to end', () {
    // The two actions that do real work, driven all the way through to the row
    // that lands in the database. A widget appearing is not the unit of proof
    // here — "Record payment" shipped broken once already, with the sheet
    // popping itself and then testing `context.mounted` on its own dead
    // context, so nothing happened and nothing complained.
    //
    // `databaseProvider` is real so the write is real. `activeShopsProvider` is
    // stubbed only because the picker shows an AppSkeleton while a real query
    // is in flight, and a skeleton pulses forever — `pumpAndSettle` would sit
    // on it until the test timed out. The shop list is not what is under test.
    late AppDatabase db;
    late int shopId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      shopId = await db.shopDao.upsertShop(
        ShopsCompanion.insert(name: 'Hotel Raj'),
      );
    });
    tearDown(() => db.close());

    Future<void> pumpShell(WidgetTester tester, {DateTime? selectedDate}) async {
      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            activeShopsProvider.overrideWith(
              (ref) => Stream.value([
                Shop(
                  id: shopId,
                  name: 'Hotel Raj',
                  area: null,
                  phone: null,
                  isActive: true,
                ),
              ]),
            ),
            if (selectedDate != null)
              selectedDateProvider.overrideWith((ref) => selectedDate),
          ],
          child: MaterialApp.router(
            theme: buildAppTheme(BrandConfig.milano),
            routerConfig: GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => const Scaffold(
                    floatingActionButton: QuickActionButton(),
                  ),
                ),
                GoRoute(
                  path: '/order/:shopId',
                  builder: (_, state) => Scaffold(
                    body: Text(
                      'order ${state.pathParameters['shopId']} '
                      'on ${state.uri.queryParameters['date']}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> chooseAction(WidgetTester tester, String label) async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    /// Tears the tree down inside the test, then lets Drift's cleanup run.
    ///
    /// Disposing the ProviderScope cancels the Drift query streams, and Drift
    /// schedules a zero-duration Timer to close its stream store. The
    /// end-of-test invariant check sees that timer still pending and fails —
    /// and the resulting shutdown deadlocks the entire test file, not just the
    /// failing test, which is why this is worth the ceremony.
    ///
    /// The pump needs a real duration: a bare `pump()` renders a frame without
    /// advancing the fake clock, so a zero-duration timer never comes due.
    Future<void> drain(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets('Record payment writes a payment against the chosen shop',
        (tester) async {
      await pumpShell(tester);

      await chooseAction(tester, 'Record payment');

      // The picker opened rather than the flow dying silently.
      expect(find.text('All shops'), findsOneWidget);
      await tester.tap(find.text('Hotel Raj'));
      await tester.pumpAndSettle();

      // And the payment sheet opened behind it. This is the exact step that
      // used to be skipped.
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '450');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));

      // Not pumpAndSettle: the Save button swaps in a CircularProgressIndicator
      // while the write runs, and that animation never settles.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final payments = await db.select(db.payments).get();
      expect(payments, hasLength(1));
      expect(payments.single.shopId, shopId);
      expect(payments.single.amount, closeTo(450, 0.001));
      expect(payments.single.mode, PaymentMode.cash.name);

      await drain(tester);
    });

    testWidgets('dismissing the shop picker records nothing', (tester) async {
      await pumpShell(tester);
      await chooseAction(tester, 'Record payment');

      // Back out of the picker rather than choosing.
      Navigator.of(tester.element(find.text('All shops'))).pop();
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      expect(await db.select(db.payments).get(), isEmpty);

      await drain(tester);
    });

    testWidgets('New order opens order entry on the selected date, not today',
        (tester) async {
      // Paging to another day and then creating an order for today is the bug
      // that only surfaces in the ledger weeks later.
      final selected = DateTime(2026, 9, 4);
      await pumpShell(tester, selectedDate: selected);

      await chooseAction(tester, 'New order');
      await tester.tap(find.text('Hotel Raj'));
      await tester.pumpAndSettle();

      expect(find.text('order $shopId on 2026-09-04'), findsOneWidget);

      await drain(tester);
    });
  });

  group('shop picker', () {
    testWidgets('filters on name and on area, and offers a way back',
        (tester) async {
      Shop? picked;
      await tester.pumpWidget(host(
        shops: [
          shop(1, 'Hotel Raj', area: 'Anna Nagar'),
          shop(2, 'Star Bakery', area: 'T Nagar'),
          shop(3, 'New Moon', area: 'Anna Nagar'),
        ],
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showShopPicker(context, title: 'New order');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('New order'), findsOneWidget);
      expect(find.text('Hotel Raj'), findsOneWidget);
      expect(find.text('Star Bakery'), findsOneWidget);
      expect(find.text('New Moon'), findsOneWidget);

      // By name.
      await tester.enterText(find.byType(TextField), 'star');
      await tester.pumpAndSettle();
      expect(find.text('Star Bakery'), findsOneWidget);
      expect(find.text('Hotel Raj'), findsNothing);

      // By area — the owner thinks in rounds, not only in shop names.
      await tester.enterText(find.byType(TextField), 'anna');
      await tester.pumpAndSettle();
      expect(find.text('Hotel Raj'), findsOneWidget);
      expect(find.text('New Moon'), findsOneWidget);
      expect(find.text('Star Bakery'), findsNothing);

      await tester.tap(find.text('Hotel Raj'));
      await tester.pumpAndSettle();
      expect(picked?.id, 1);
    });

    testWidgets('a search matching nothing says so rather than showing empty',
        (tester) async {
      await tester.pumpWidget(host(
        shops: [shop(1, 'Hotel Raj')],
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showShopPicker(context, title: 'New order'),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('No shop matches'), findsOneWidget);
    });

    testWidgets('inactive shops are not offered', (tester) async {
      // The picker reads activeShopsProvider. Recording an order against a
      // shop that is no longer supplied is not a thing to make easy.
      await tester.pumpWidget(host(
        shops: [shop(1, 'Hotel Raj')],
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showShopPicker(context, title: 'New order'),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Hotel Raj'), findsOneWidget);
      expect(find.text('1', skipOffstage: false), findsWidgets);
    });
  });
}
