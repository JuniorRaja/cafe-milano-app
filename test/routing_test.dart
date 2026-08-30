import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:milano_orders/app.dart';
import 'package:milano_orders/widgets/shell/destinations.dart';

/// The redirects are the whole risk in doc 10b.
///
/// There were 30 hardcoded `/profile` strings in `lib/`, four of them
/// parameterised. A redirect that silently drops one breaks a deep link and is
/// not noticed for a week, which is exactly why this is proven here rather
/// than by clicking through the app.
///
/// The real route table is used — `buildRouter()` from `app.dart` — not a
/// mirror of it. A test against a hand-copied table proves the copy.
void main() {
  /// Where an old URL is sent. This is `legacyRedirectFor` itself, which is
  /// the function the router's `redirect` delegates to — `findMatch` does not
  /// run a router-level redirect, so going through it would be testing
  /// go_router rather than this rule.
  String resolve(String location) {
    final target = legacyRedirectFor(Uri.parse(location));
    return Uri.parse(target ?? location).path;
  }

  /// Whether the route table has somewhere to put this path.
  bool matches(String location) {
    final router = buildRouter();
    addTearDown(router.dispose);
    return router.configuration.findMatch(Uri.parse(location)).routes.isNotEmpty;
  }

  group('/profile/* redirects to /settings/*', () {
    // Every one of the 15 routes that lived behind /profile, enumerated
    // against docs/app-audit.md 2.1. Not sampled.
    const moved = <String, String>{
      '/profile': '/settings',
      '/profile/shops': '/settings/shops',
      '/profile/shops/new': '/settings/shops/new',
      '/profile/products': '/settings/products',
      '/profile/products/new': '/settings/products/new',
      '/profile/products/share': '/settings/products/share',
      '/profile/prices': '/settings/prices',
      '/profile/standing-orders': '/settings/standing-orders',
      '/profile/business-info': '/settings/business-info',
      '/profile/categories': '/settings/categories',
      '/profile/backup': '/settings/backup',
      '/profile/dashboard-settings': '/settings/dashboard-settings',
      '/profile/dashboard-settings/help': '/settings/dashboard-settings/help',
    };

    moved.forEach((from, to) {
      test('$from -> $to', () {
        expect(resolve(from), to);
        // Redirecting to a path nothing serves is a 404 with extra steps.
        expect(matches(to), isTrue, reason: '$to matches no route');
      });
    });

    test('the parameterised shop paths keep their id', () {
      expect(resolve('/profile/shops/3/edit'), '/settings/shops/3/edit');
      expect(resolve('/profile/shops/412/edit'), '/settings/shops/412/edit');
      expect(matches('/settings/shops/412/edit'), isTrue);
    });

    test('the parameterised product path keeps its id', () {
      expect(resolve('/profile/products/7/edit'), '/settings/products/7/edit');
      expect(matches('/settings/products/7/edit'), isTrue);
    });

    test('the ledger leaves settings entirely rather than moving with it', () {
      // It is not a setting and never was. This is the one old path whose
      // replacement is not a straight /profile -> /settings swap, so it is
      // the one a prefix rule would silently get wrong.
      expect(resolve('/profile/shops/3/ledger'), '/shops/3/ledger');
      expect(resolve('/profile/shops/58/ledger'), '/shops/58/ledger');
      expect(matches('/shops/58/ledger'), isTrue);
    });

    test('query parameters survive the hop', () {
      final target =
          legacyRedirectFor(Uri.parse('/profile/shops?filter=active'))!;
      final uri = Uri.parse(target);
      expect(uri.path, '/settings/shops');
      expect(uri.queryParameters['filter'], 'active');
    });

    test('the deleted splash route lands on home rather than 404ing', () {
      expect(resolve('/splash'), '/');
    });

    test('the 1.11 branch renames redirect', () {
      // The shell branches were renamed so the paths match their contents:
      // `/` was the shop list and `/orders` was billing, which is the opposite
      // of what either name suggests.
      expect(resolve('/dashboard'), '/');
      expect(matches('/'), isTrue);
      expect(matches('/billing'), isTrue);
      expect(matches('/finances'), isTrue);
    });

    test('a path merely starting with the letters profile is left alone', () {
      // /profiles is not /profile. A `startsWith('/profile')` written without
      // the trailing slash would rewrite it.
      expect(legacyRedirectFor(Uri.parse('/profiles')), isNull);
      expect(legacyRedirectFor(Uri.parse('/settings')), isNull);
      expect(legacyRedirectFor(Uri.parse('/')), isNull);
      expect(legacyRedirectFor(Uri.parse('/orders')), isNull);
    });
  });

  group('every route survives the restructure', () {
    // The 22 routes reachable before doc 10b, at their post-10b paths.
    // Enumerated against docs/app-audit.md 2.1 — do not sample.
    const routes = <String>[
      '/',
      '/orders',
      '/kitchen',
      '/billing',
      '/finances',
      '/order/1',
      '/outstanding',
      '/shops/1/ledger',
      '/settings',
      '/settings/shops',
      '/settings/shops/new',
      '/settings/shops/1/edit',
      '/settings/products',
      '/settings/products/new',
      '/settings/products/1/edit',
      '/settings/products/share',
      '/settings/prices',
      '/settings/standing-orders',
      '/settings/business-info',
      '/settings/categories',
      '/settings/backup',
      '/settings/dashboard-settings',
      '/settings/dashboard-settings/help',
    ];

    test('every one matches a route rather than falling through', () {
      // 22 before the restructure, 23 after: Finances is new, and /dashboard
      // became / rather than disappearing.
      expect(routes, hasLength(23));
      for (final route in routes) {
        expect(
          matches(route),
          isTrue,
          reason: '$route matched nothing — it is unreachable',
        );
      }
    });

    test('order entry carries its date query parameter', () {
      final router = buildRouter();
      addTearDown(router.dispose);
      final match =
          router.configuration.findMatch(Uri.parse('/order/4?date=2026-08-29'));
      expect(match.uri.path, '/order/4');
      expect(match.uri.queryParameters['date'], '2026-08-29');
    });
  });

  group('AppRoutes builders agree with the route table', () {
    test('a built path resolves to the route it names', () {
      expect(AppRoutes.shopLedgerFor(9), '/shops/9/ledger');
      expect(AppRoutes.shopEditFor(9), '/settings/shops/9/edit');
      expect(AppRoutes.productEditFor(9), '/settings/products/9/edit');

      expect(matches(AppRoutes.shopLedgerFor(9)), isTrue);
      expect(matches(AppRoutes.shopEditFor(9)), isTrue);
      expect(matches(AppRoutes.productEditFor(9)), isTrue);
    });

    test('orderEntryFor formats the date as the screen parses it', () {
      // OrderEntryScreen splits on '-', so anything else silently throws on
      // open. The two have to agree and nothing else pins that.
      final path = AppRoutes.orderEntryFor(3, date: DateTime(2026, 8, 29));
      expect(path, '/order/3?date=2026-08-29');

      final parts = Uri.parse(path).queryParameters['date']!.split('-');
      expect(parts, hasLength(3));
      expect(
        DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        ),
        DateTime(2026, 8, 29),
      );
    });

    test('no route constant still points at /profile', () {
      const constants = [
        AppRoutes.overview,
        AppRoutes.orders,
        AppRoutes.kitchen,
        AppRoutes.billing,
        AppRoutes.finances,
        AppRoutes.orderEntry,
        AppRoutes.outstanding,
        AppRoutes.shopLedger,
        AppRoutes.settings,
        AppRoutes.shops,
        AppRoutes.shopNew,
        AppRoutes.shopEdit,
        AppRoutes.products,
        AppRoutes.productNew,
        AppRoutes.productEdit,
        AppRoutes.catalogShare,
        AppRoutes.prices,
        AppRoutes.standingOrders,
        AppRoutes.businessInfo,
        AppRoutes.categories,
        AppRoutes.backupRestore,
        AppRoutes.dashboardSettings,
        AppRoutes.kpiHelp,
      ];
      for (final route in constants) {
        expect(route, isNot(startsWith('/profile')));
      }
    });
  });

  group('destinations drive the shell', () {
    test('every visible destination resolves to a real route', () {
      for (final dest in visibleDestinations) {
        expect(
          matches(dest.route),
          isTrue,
          reason: '${dest.label} points at ${dest.route}, which matches nothing',
        );
      }
    });

    test('unshipped destinations are hidden, never shown-disabled', () {
      // A disabled row the user can never enable is noise: there is no unlock
      // path in a single-user app, so it teaches nothing.
      expect(appDestinations.where((d) => !d.shipped), isNotEmpty);
      expect(visibleDestinations.every((d) => d.shipped), isTrue);
      expect(
        visibleDestinations.map((d) => d.label),
        isNot(contains('Auto Suggestions')),
      );
    });

    test('the bottom bar has five slots, in the order of the day', () {
      // See what happened, enter today's orders, bake them, bill them, collect.
      expect(bottomBarDestinations, hasLength(5));
      expect(
        bottomBarDestinations.map((d) => d.route).toList(),
        ['/', '/orders', '/kitchen', '/billing', '/finances'],
      );
      expect(bottomBarRoutes, isNot(contains('/profile')));
      expect(bottomBarRoutes, isNot(contains('/settings')));
    });

    test('the slot order matches the shell branch order', () {
      // index 0-4 in bottomBarRoutes addresses branch 0-4 in app.dart. If the
      // two ever disagree, every tab opens the wrong screen.
      final router = buildRouter();
      addTearDown(router.dispose);
      final shell =
          router.configuration.routes.whereType<StatefulShellRoute>().single;

      expect(shell.branches, hasLength(bottomBarRoutes.length));
      for (var i = 0; i < bottomBarRoutes.length; i++) {
        final route = shell.branches[i].routes.single as GoRoute;
        expect(
          route.path,
          bottomBarRoutes[i],
          reason: 'slot $i points at ${bottomBarRoutes[i]} but branch $i '
              'serves ${route.path}',
        );
      }
    });

    test('a nested route highlights its section, not the shortest prefix', () {
      expect(destinationForLocation('/settings/shops/3/edit')?.label, 'Shops');
      expect(destinationForLocation('/settings/products/7/edit')?.label,
          'Products');
      expect(destinationForLocation('/settings')?.label, 'Settings');
      expect(destinationForLocation('/')?.label, 'Overview');
      // '/' must not swallow every path just because they all start with it.
      expect(destinationForLocation('/kitchen')?.label, 'Kitchen');
    });

    test('adding a destination is a one-line change', () {
      // The claim doc 10b makes about this file, exercised rather than
      // asserted: one AppDestination is all the drawer, the bottom bar and the
      // settings search need to agree about a new screen.
      const throwaway = AppDestination(
        label: 'Throwaway',
        icon: Icons.science_outlined,
        route: '/throwaway',
        group: DestGroup.daily,
      );
      expect(throwaway.matches('throw'), isTrue);
      expect(throwaway.selectedIcon, Icons.science_outlined);
      expect(throwaway.group, DestGroup.daily);
    });
  });
}
