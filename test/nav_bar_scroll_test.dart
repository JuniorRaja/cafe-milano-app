// The bottom bar hiding on scroll.
//
// The riskiest change in the device pass: the bar left
// `Scaffold.bottomNavigationBar`, which was insetting the body of all five
// branch screens. That slot is why it could not be animated — sliding it would
// have relaid out the whole screen on every frame — so it is an overlay now,
// and each screen leaves its own room with `AppShell.bottomInset`.
// See docs/features/10b-device-pass.md, J1.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/providers/ledger_provider.dart';
import 'package:milano_orders/providers/shop_provider.dart';
import 'package:milano_orders/theme/app_theme.dart';
import 'package:milano_orders/theme/brand_config.dart';
import 'package:milano_orders/widgets/floating_nav_bar.dart';
import 'package:milano_orders/widgets/shell/app_shell.dart';
import 'package:milano_orders/widgets/shell/destinations.dart';

void main() {
  /// A page with a long vertical list and, above it, a horizontal strip — the
  /// shape every branch screen has: chips or date pills over a list.
  Widget branchBody() => Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < 20; i++)
                  SizedBox(width: 90, child: Text('Chip $i')),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 60, child: Text('Row $i')),
              ],
            ),
          ),
        ],
      );

  Widget host({bool reducedMotion = false}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            for (final route in bottomBarRoutes)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: route,
                    builder: (_, _) =>
                        route == '/' ? branchBody() : const SizedBox.expand(),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    return ProviderScope(
      overrides: [
        activeShopsProvider.overrideWith((ref) => Stream.value(const <Shop>[])),
        outstandingByShopProvider.overrideWith((ref) => Stream.value(const [])),
        outstandingSummaryProvider.overrideWith(
          (ref) => Stream.value(OutstandingSummary.empty),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(420, 900),
          disableAnimations: reducedMotion,
        ),
        child: MaterialApp.router(
          theme: buildAppTheme(BrandConfig.milano),
          routerConfig: router,
        ),
      ),
    );
  }

  /// 0 while the bar is up, 1 once it has slid off the bottom.
  double slide(WidgetTester tester) =>
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset.dy;

  Finder list() => find.byType(ListView).last;

  testWidgets('the bar is an overlay, not a Scaffold slot', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byType(FloatingNavBar), findsOneWidget);
    // The slot is what insets the body, and what made the bar unanimatable.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.bottomNavigationBar, isNull);
  });

  testWidgets('scrolling down hides it, scrolling back up brings it back',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(slide(tester), 0);

    await tester.drag(list(), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(slide(tester), 1, reason: 'scrolling down should hide the bar');

    await tester.drag(list(), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(slide(tester), 0, reason: 'scrolling up should bring it back');
  });

  testWidgets('coming back to the top shows it', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.drag(list(), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(slide(tester), 1);

    // All the way back. The last gesture is upward, so this also covers the
    // case where the list settles at the very top.
    await tester.drag(list(), const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(slide(tester), 0);
  });

  testWidgets('swiping a horizontal strip is not scrolling the page',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(slide(tester), 0, reason: 'a chip row is not a page scroll');
  });

  testWidgets('reduced motion keeps the bar where it is', (tester) async {
    // A control that vanishes is exactly the movement the setting turns off,
    // and hiding it without the slide would be worse rather than better.
    await tester.pumpWidget(host(reducedMotion: true));
    await tester.pumpAndSettle();

    await tester.drag(list(), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(slide(tester), 0);
  });

  testWidgets('the inset leaves room for the bar and the gesture area',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(FloatingNavBar));
    expect(
      AppShell.bottomInset(context),
      greaterThanOrEqualTo(FloatingNavBar.height),
      reason: 'a screen must never end flush under the bar',
    );
  });
}
