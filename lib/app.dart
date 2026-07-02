import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/kitchen/kitchen_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/shops/shop_list_screen.dart';
import 'screens/profile/shops/shop_form_screen.dart';
import 'screens/profile/products/product_list_screen.dart';
import 'screens/profile/products/product_form_screen.dart';
import 'screens/profile/prices/price_matrix_screen.dart';
import 'screens/profile/standing_orders/standing_orders_screen.dart';
import 'screens/order_entry/order_entry_screen.dart';

// Brand colors extracted from the Caffe Milano logo
const kBrandGold   = Color(0xFFFFC000); // logo background — primary seed
const kBrandBrown  = Color(0xFF4A2C2A); // espresso — active/selected states, icon & text accents
const kBrandMaroon = Color(0xFFB71C1C); // logo ring + inner circle — reserved for brand-mark use, not seeded
const kSurface     = Color(0xFFFFFBF5); // warm cream

class AppRoutes {
  static const splash        = '/splash';
  static const home          = '/';
  static const orders        = '/orders';
  static const kitchen       = '/kitchen';
  static const profile       = '/profile';
  static const orderEntry    = '/order/:shopId';
  static const shops         = '/profile/shops';
  static const shopNew       = '/profile/shops/new';
  static const shopEdit      = '/profile/shops/:id/edit';
  static const products      = '/profile/products';
  static const productNew    = '/profile/products/new';
  static const productEdit   = '/profile/products/:id/edit';
  static const prices        = '/profile/prices';
  static const standingOrders = '/profile/standing-orders';
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
            builder: (context, state) => const HomeScreen(),
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
            ],
          ),
        ]),
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

class MilanoOrdersApp extends StatelessWidget {
  const MilanoOrdersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Milano Orders',
      theme: ThemeData(
        useMaterial3: true,
        visualDensity: VisualDensity.compact,
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: kBrandGold,
          surface: kSurface,
        ),
        listTileTheme: const ListTileThemeData(
          dense: true,
          visualDensity: VisualDensity.compact,
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 64,
          indicatorColor: Colors.transparent,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: kBrandBrown);
            }
            return IconThemeData(color: Colors.grey.shade600);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return GoogleFonts.poppins(
                color: kBrandBrown,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              );
            }
            return GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontSize: 11,
            );
          }),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: kBrandBrown,
          unselectedLabelColor: Colors.grey,
          indicatorColor: kBrandBrown,
          dividerColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}

const _topLevelPaths = {'/', '/orders', '/kitchen', '/profile'};

class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final showNavBar = _topLevelPaths.contains(location);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: showNavBar
          ? NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Orders',
                ),
                NavigationDestination(
                  icon: Icon(Icons.restaurant_outlined),
                  selectedIcon: Icon(Icons.restaurant),
                  label: 'Kitchen',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }
}
