import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

class AppRoutes {
  static const home = '/';
  static const orders = '/orders';
  static const kitchen = '/kitchen';
  static const profile = '/profile';
  static const orderEntry = '/order/:shopId';
  static const shops = '/profile/shops';
  static const shopNew = '/profile/shops/new';
  static const shopEdit = '/profile/shops/:id/edit';
  static const products = '/profile/products';
  static const productNew = '/profile/products/new';
  static const productEdit = '/profile/products/:id/edit';
  static const prices = '/profile/prices';
  static const standingOrders = '/profile/standing-orders';
}

final _router = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
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

class BakeOrderApp extends StatelessWidget {
  const BakeOrderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BakeOrder',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF57C00),
          surface: const Color(0xFFFFFBF5),
        ),
      ),
      routerConfig: _router,
    );
  }
}

class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
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
      ),
    );
  }
}
