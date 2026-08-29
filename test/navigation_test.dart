import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:milano_orders/app.dart';

/// Why the shop ledger is a top-level route rather than a settings child.
///
/// go_router keys a shell's page off the shell route object itself, so pushing
/// a route *nested under* a `StatefulShellRoute` from a route *outside* it puts
/// two pages with the same key into the root navigator and trips Navigator's
/// duplicate-page-key assertion.
///
/// Before doc 10b the app worked around that by registering the ledger twice —
/// once under `/profile/shops/:id/ledger` inside the shell, once under
/// `/outstanding/:id/ledger` outside it — so the path in from the dashboard did
/// not re-enter the shell. Two registrations of one screen is a workaround, not
/// a design, and the second one was reachable by a URL nobody would guess.
///
/// 10b moved the ledger to `/shops/:id/ledger` at the top level instead. One
/// registration, pushable from the shell and from Outstanding alike. The first
/// test still pins the constraint, because it is the reason for the shape; the
/// second pins that the real route table now has that shape.
void main() {
  test('the ledger is registered once, and outside the shell', () {
    final router = buildRouter();
    addTearDown(router.dispose);

    String? pathOf(RouteBase route) =>
        route is GoRoute ? route.path : null;

    final topLevel = router.configuration.routes;
    final shells = topLevel.whereType<StatefulShellRoute>();
    expect(shells, hasLength(1), reason: 'the app has exactly one shell');

    // Registered at the top level, next to the shell rather than inside it.
    expect(
      topLevel.map(pathOf),
      contains(AppRoutes.shopLedger),
      reason: '${AppRoutes.shopLedger} must be a top-level route',
    );

    // And nowhere inside any branch, or the duplicate-key bug comes back.
    for (final branch in shells.single.branches) {
      for (final route in branch.routes) {
        expect(
          _pathsUnder(route),
          isNot(contains(contains('ledger'))),
          reason: 'the ledger must not be registered inside the shell',
        );
      }
    }

    // The whole point: exactly one route serves it.
    expect(
      topLevel.map(pathOf).where((p) => p == AppRoutes.shopLedger),
      hasLength(1),
    );
  });

  testWidgets('a route outside the shell can push another outside it',
      (tester) async {
    // The real path a user walks: shell → Outstanding → a shop's ledger.
    // Both hops are outside the shell, which is what makes them legal.
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/', builder: (c, s) => const Text('home')),
            ]),
          ],
        ),
        GoRoute(
          path: '/outstanding',
          builder: (c, s) => const Text('outstanding'),
        ),
        GoRoute(
          path: '/shops/:id/ledger',
          builder: (c, s) => const Text('ledger'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    unawaited(router.push('/outstanding'));
    await tester.pumpAndSettle();
    expect(find.text('outstanding'), findsOneWidget);

    unawaited(router.push('/shops/3/ledger'));
    await tester.pumpAndSettle();
    expect(find.text('ledger'), findsOneWidget);

    // And back out again, one hop at a time.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('outstanding'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}

/// Every path registered at or under [route].
List<String> _pathsUnder(RouteBase route) => [
      if (route is GoRoute) route.path,
      for (final child in route.routes) ..._pathsUnder(child),
    ];
