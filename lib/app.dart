import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'theme/brand_config.dart';
import 'theme/tokens.dart';
import 'widgets/floating_nav_bar.dart';
import 'widgets/app_background.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/home/home_shops_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/kitchen/kitchen_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/shops/shop_list_screen.dart';
import 'screens/profile/shops/shop_form_screen.dart';
import 'screens/ledger/outstanding_list_screen.dart';
import 'screens/ledger/shop_ledger_screen.dart';
import 'screens/profile/products/product_list_screen.dart';
import 'screens/profile/products/product_form_screen.dart';
import 'screens/profile/prices/price_matrix_screen.dart';
import 'screens/profile/standing_orders/standing_orders_screen.dart';
import 'screens/profile/business_info/business_info_form_screen.dart';
import 'screens/profile/products/catalog_share_picker_screen.dart';
import 'screens/profile/backup/backup_restore_screen.dart';
import 'screens/profile/categories/category_list_screen.dart';
import 'screens/profile/dashboard_settings_screen.dart';
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

class AppRoutes {
  static const splash        = '/splash';
  static const home          = '/';
  static const dashboard     = '/dashboard';
  static const orders        = '/orders';
  static const kitchen       = '/kitchen';
  static const profile       = '/profile';
  static const orderEntry    = '/order/:shopId';
  static const shops         = '/profile/shops';
  static const shopNew       = '/profile/shops/new';
  static const shopEdit      = '/profile/shops/:id/edit';
  static const shopLedger    = '/profile/shops/:id/ledger';
  static const outstanding   = '/outstanding';
  static const products      = '/profile/products';
  static const productNew    = '/profile/products/new';
  static const productEdit   = '/profile/products/:id/edit';
  static const prices        = '/profile/prices';
  static const standingOrders = '/profile/standing-orders';
  static const businessInfo  = '/profile/business-info';
  static const catalogShare  = '/profile/products/share';
  static const categories    = '/profile/categories';
  static const backupRestore = '/profile/backup';
  static const dashboardSettings = '/profile/dashboard-settings';
  static const kpiHelp       = '/profile/dashboard-settings/help';
}

final _router = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _ScaffoldWithNavBar(navigationShell: navigationShell),
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
        StatefulShellBranch(routes: [
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'shops',
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
                  GoRoute(
                    path: ':id/ledger',
                    builder: (context, state) => ShopLedgerScreen(
                      shopId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'products',
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
                path: 'prices',
                builder: (context, state) => const PriceMatrixScreen(),
              ),
              GoRoute(
                path: 'standing-orders',
                builder: (context, state) => const StandingOrdersScreen(),
              ),
              GoRoute(
                path: 'business-info',
                builder: (context, state) => const BusinessInfoFormScreen(),
              ),
              GoRoute(
                path: 'categories',
                builder: (context, state) => const CategoryListScreen(),
              ),
              GoRoute(
                path: 'backup',
                builder: (context, state) => const BackupRestoreScreen(),
              ),
              GoRoute(
                path: 'dashboard-settings',
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
            ],
          ),
        ]),
      ],
    ),
    // Dashboard as a top-level push route (opened from FAB)
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (context, state) => const DashboardScreen(),
    ),
    // Receivables list, pushed from the dashboard's Outstanding card.
    //
    // The ledger is registered again as a child here, rather than reusing
    // AppRoutes.shopLedger inside the shell. A route under the
    // StatefulShellRoute cannot be pushed from a top-level route: the shell's
    // page key is derived from the shell route object itself, so re-entering
    // it puts two pages with the same key into the root navigator and trips
    // Navigator's duplicate-page-key assertion. Dashboard and Outstanding both
    // live outside the shell, so the path into a shop's ledger from here has
    // to stay outside it too.
    GoRoute(
      path: AppRoutes.outstanding,
      builder: (context, state) => const OutstandingListScreen(),
      routes: [
        GoRoute(
          path: ':id/ledger',
          builder: (context, state) => ShopLedgerScreen(
            shopId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/order/:shopId',
      builder: (context, state) => OrderEntryScreen(
        shopId: int.parse(state.pathParameters['shopId']!),
        date: state.uri.queryParameters['date'],
      ),
    ),
  ],
);

class OrdersApp extends ConsumerWidget {
  const OrdersApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    return MaterialApp.router(
      title: brand.appName,
      theme: buildAppTheme(brand),
      routerConfig: _router,
    );
  }
}

const _topLevelPaths = {'/', '/orders', '/kitchen', '/profile', '/dashboard'};

class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final showNavBar = _topLevelPaths.contains(location);

    // The background sits *outside* the Scaffold, not in its body.
    //
    // `bottomNavigationBar` insets the body, so a body-level background is
    // laid out ~80px shorter on shell routes than on sub-routes, where the
    // nav bar is absent. `BoxFit.cover` recomputes its crop against that
    // shorter box, so popping back from a sub-route visibly rescaled the
    // artwork mid-transition. Out here its box is the whole screen in both
    // states and never changes.
    return ColoredBox(
      color: AppColors.bg,
      child: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: navigationShell,
            bottomNavigationBar: showNavBar
                ? FloatingNavBar(
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: (index) => navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    ),
                  )
                : null,
            floatingActionButton: showNavBar
                ? FloatingActionButton(
                    onPressed: () =>
                        GoRouter.of(context).push(AppRoutes.dashboard),
                    child: const Icon(Icons.dashboard_rounded),
                  )
                : null,
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
          ),
        ],
      ),
    );
  }
}
