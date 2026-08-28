import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Mirrors the shape of the route table in lib/app.dart — a
/// StatefulShellRoute holding the app's branches, plus Dashboard and
/// Outstanding as top-level routes pushed from inside it.
///
/// The rule this pins down: a route nested under the StatefulShellRoute cannot
/// be pushed from a top-level route. go_router keys the shell's page off the
/// shell route object itself, so re-entering the shell puts two pages with the
/// same key into the root navigator and trips Navigator's duplicate-page-key
/// assertion. Anything reachable from Dashboard or Outstanding therefore has to
/// be registered outside the shell too, which is why the shop ledger appears in
/// the route table twice.
GoRouter _buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/', builder: (c, s) => const Text('home')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/profile',
                builder: (c, s) => const Text('profile'),
                routes: [
                  GoRoute(
                    path: 'shops',
                    builder: (c, s) => const Text('shops'),
                    routes: [
                      GoRoute(
                        path: ':id/ledger',
                        builder: (c, s) => const Text('ledger in shell'),
                      ),
                    ],
                  ),
                ],
              ),
            ]),
          ],
        ),
        GoRoute(path: '/dashboard', builder: (c, s) => const Text('dashboard')),
        GoRoute(
          path: '/outstanding',
          builder: (c, s) => const Text('outstanding'),
          routes: [
            GoRoute(
              path: ':id/ledger',
              builder: (c, s) => const Text('ledger'),
            ),
          ],
        ),
      ],
    );

void main() {
  testWidgets('a shop ledger opens from the dashboard route chain',
      (tester) async {
    final router = _buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // The real path a user walks: shell → dashboard → outstanding card →
    // a shop's ledger. Every hop after the first is outside the shell.
    unawaited(router.push('/dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('dashboard'), findsOneWidget);

    unawaited(router.push('/outstanding'));
    await tester.pumpAndSettle();
    expect(find.text('outstanding'), findsOneWidget);

    unawaited(router.push('/outstanding/3/ledger'));
    await tester.pumpAndSettle();
    expect(find.text('ledger'), findsOneWidget);

    // And back out again, one hop at a time.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('outstanding'), findsOneWidget);
  });
}
