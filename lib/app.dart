import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'theme/brand_config.dart';
import 'theme/tokens.dart';
import 'widgets/shell/app_bootstrap_gate.dart';
import 'widgets/shell/app_lifecycle_scope.dart';
import 'widgets/shell/app_shell.dart';
import 'screens/home/home_shops_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/kitchen/kitchen_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/shops/shop_list_screen.dart';
import 'screens/settings/shops/shop_form_screen.dart';
import 'screens/ledger/outstanding_list_screen.dart';
import 'screens/ledger/shop_ledger_screen.dart';
import 'screens/settings/products/product_list_screen.dart';
import 'screens/settings/products/product_form_screen.dart';
import 'screens/settings/prices/price_matrix_screen.dart';
import 'screens/settings/standing_orders/standing_orders_screen.dart';
import 'screens/settings/business_info/business_info_form_screen.dart';
import 'screens/settings/products/catalog_share_picker_screen.dart';
import 'screens/settings/backup/backup_restore_screen.dart';
import 'screens/settings/categories/category_list_screen.dart';
import 'screens/settings/dashboard_settings_screen.dart';
import 'screens/dashboard/kpi_help_screen.dart';
import 'screens/order_entry/order_entry_screen.dart';

// Deprecated brand-colour aliases onto the design tokens.
//
// 60+ files import these. Removing them in this release would turn a
// foundation change into a 60-file diff with no reviewable seam, so they stay
// and the analyzer warning count is the progress bar: doc 10c drives it to
// zero and then deletes them. Do not add new uses.
@Deprecated('Use AppColors.brandPrimary, or brandProvider for the live value.')
const kBrandGold = AppColors.brandPrimary;
@Deprecated('Use AppColors.brandDeep, or brandProvider for the live value.')
const kBrandBrown = AppColors.brandDeep;
@Deprecated('Use AppColors.brandMark — logo mark only, never a UI colour.')
const kBrandMaroon = AppColors.brandMark;
@Deprecated('Use AppColors.bg.')
const kSurface = AppColors.bg;
@Deprecated('Use brandProvider.logoAsset.')
const kDefaultLogoAsset = 'mobile-app-logo-trasnsp.png';

/// Every route in the app. Nothing outside this class writes a route string —
/// the parameterised ones have builders below for exactly that reason.
///
/// `/profile/*` became `/settings/*` in doc 10b. `_legacyRedirect` keeps every
/// old path working; see the note there before removing it.
class AppRoutes {
  // Shell branches — the four bottom-bar slots, in order.
  static const home = '/';
  static const orders = '/orders';
  static const kitchen = '/kitchen';
  static const dashboard = '/dashboard';

  // Pushed over the shell.
  static const orderEntry = '/order/:shopId';
  static const outstanding = '/outstanding';

  /// The shop ledger is not a setting and never was. It sits at the top level
  /// so it can be pushed from the shell, from Outstanding and from the shop
  /// list without being registered three times.
  static const shopLedger = '/shops/:id/ledger';

  static const settings = '/settings';
  static const shops = '/settings/shops';
  static const shopNew = '/settings/shops/new';
  static const shopEdit = '/settings/shops/:id/edit';
  static const products = '/settings/products';
  static const productNew = '/settings/products/new';
  static const productEdit = '/settings/products/:id/edit';
  static const catalogShare = '/settings/products/share';
  static const prices = '/settings/prices';
  static const standingOrders = '/settings/standing-orders';
  static const businessInfo = '/settings/business-info';
  static const categories = '/settings/categories';
  static const backupRestore = '/settings/backup';
  static const dashboardSettings = '/settings/dashboard-settings';
  static const kpiHelp = '/settings/dashboard-settings/help';

  // --- Parameterised paths -------------------------------------------------
  // Filling `:id` by hand at a call site is how 30 hardcoded `/profile`
  // strings accumulated in the first place. These are the only supported way.

  static String shopLedgerFor(int shopId) => '/shops/$shopId/ledger';
  static String shopEditFor(int shopId) => '/settings/shops/$shopId/edit';
  static String productEditFor(int productId) =>
      '/settings/products/$productId/edit';

  static String orderEntryFor(int shopId, {DateTime? date}) {
    final path = '/order/$shopId';
    if (date == null) return path;
    final iso = date.toIso8601String().split('T').first;
    return '$path?date=$iso';
  }
}

/// Keeps every pre-10b URL working.
///
/// This is the whole risk in the 10b release: there were 30 hardcoded
/// `/profile` strings in `lib/`, four of them parameterised, and a broken deep
/// link is not noticed for a week. One prefix rule covers all of them,
/// including paths this file never enumerates, and `test/routing_test.dart`
/// pins it.
///
/// Delete only once no installed build can still hold an old link.
/// Pure so it can be tested as itself. `findMatch` does not run a router-level
/// redirect, so a test that went through the router would be testing go_router
/// rather than this rule.
String? legacyRedirectFor(Uri uri) {
  final path = uri.path;

  // The splash route is gone — the native splash covers cold start now.
  if (path == '/splash') return AppRoutes.home;

  // The trailing slash matters: `/profiles` is not `/profile`.
  if (path != '/profile' && !path.startsWith('/profile/')) return null;

  // The ledger did not move to /settings with the rest; it left entirely.
  final ledger = RegExp(r'^/profile/shops/(\d+)/ledger$').firstMatch(path);
  if (ledger != null) {
    return AppRoutes.shopLedgerFor(int.parse(ledger.group(1)!));
  }

  final moved = path == '/profile'
      ? AppRoutes.settings
      : '${AppRoutes.settings}${path.substring('/profile'.length)}';
  // `replace` rather than a bare string so query parameters survive the hop.
  return uri.replace(path: moved).toString();
}

String? _legacyRedirect(BuildContext context, GoRouterState state) =>
    legacyRedirectFor(state.uri);

GoRouter buildRouter() => GoRouter(
      initialLocation: AppRoutes.home,
      redirect: _legacyRedirect,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeShopsScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: AppRoutes.orders,
                builder: (context, state) => const OrdersScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: AppRoutes.kitchen,
                builder: (context, state) => const KitchenScreen(),
              ),
            ]),
            // Dashboard is a real branch as of 10b, not a push route. It keeps
            // the bottom bar, keeps its own back stack, and the `_topLevelPaths`
            // entry that had never done anything finally does.
            StatefulShellBranch(routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ]),
          ],
        ),

        // Everything below is pushed *over* the shell, one page per push, so
        // back from a drawer destination lands on the tab it was opened from.
        //
        // They are siblings rather than children of /settings on purpose: as
        // children, opening Shops from the drawer would build a Settings page
        // underneath it and cost the user a second back press to leave.
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.shops,
          builder: (context, state) => const ShopListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const ShopFormScreen(),
            ),
            GoRoute(
              path: ':id/edit',
              builder: (context, state) => ShopFormScreen(
                shopId: int.parse(state.pathParameters['id']!),
              ),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.products,
          builder: (context, state) => const ProductListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const ProductFormScreen(),
            ),
            GoRoute(
              path: ':id/edit',
              builder: (context, state) => ProductFormScreen(
                productId: int.parse(state.pathParameters['id']!),
              ),
            ),
            GoRoute(
              path: 'share',
              builder: (context, state) => const CatalogSharePickerScreen(),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.prices,
          builder: (context, state) => const PriceMatrixScreen(),
        ),
        GoRoute(
          path: AppRoutes.standingOrders,
          builder: (context, state) => const StandingOrdersScreen(),
        ),
        GoRoute(
          path: AppRoutes.businessInfo,
          builder: (context, state) => const BusinessInfoFormScreen(),
        ),
        GoRoute(
          path: AppRoutes.categories,
          builder: (context, state) => const CategoryListScreen(),
        ),
        GoRoute(
          path: AppRoutes.backupRestore,
          builder: (context, state) => const BackupRestoreScreen(),
        ),
        GoRoute(
          path: AppRoutes.dashboardSettings,
          builder: (context, state) => const DashboardSettingsScreen(),
          routes: [
            GoRoute(
              path: 'help',
              builder: (context, state) => KpiHelpScreen(
                scrollToSection: state.extra as String?,
              ),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.outstanding,
          builder: (context, state) => const OutstandingListScreen(),
        ),
        GoRoute(
          path: AppRoutes.shopLedger,
          builder: (context, state) => ShopLedgerScreen(
            shopId: int.parse(state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: AppRoutes.orderEntry,
          builder: (context, state) => OrderEntryScreen(
            shopId: int.parse(state.pathParameters['shopId']!),
            date: state.uri.queryParameters['date'],
          ),
        ),
      ],
    );

/// One router for the process. Held in a provider so a test can override it
/// and so doc 10c can finish taking the router out of global scope.
final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});

class OrdersApp extends ConsumerWidget {
  const OrdersApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    return MaterialApp.router(
      title: brand.appName,
      theme: buildAppTheme(brand),
      routerConfig: ref.watch(routerProvider),
      // The gate holds the first frame until the bootstrap provider has opened
      // the database, and shows a real error screen if it cannot. The lifecycle
      // scope is the app's single AppLifecycleListener.
      builder: (context, child) =>
          AppLifecycleScope(child: AppBootstrapGate(child: child)),
    );
  }
}
