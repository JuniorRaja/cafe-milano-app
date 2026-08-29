import 'package:flutter/material.dart';

import '../../app.dart';

/// Every place in the app you can *go*, as data.
///
/// This file is the point of doc 10b. Before it, adding a destination meant
/// editing a hardcoded icon tuple array in the nav bar, a hardcoded
/// `_topLevelPaths` set in `app.dart`, and a hand-written list in the settings
/// screen — three edits, three places to forget. Docs 12, 15 and 16 each add a
/// destination. Here that is one row.
///
/// The drawer, the bottom bar and the settings search all read this list and
/// nothing else.
enum DestGroup {
  /// Above the groups, on its own — the drawer's first row.
  primary('', showHeader: false),
  daily('Daily'),
  money('Money'),
  catalogue('Catalogue'),

  /// Below the divider at the bottom of the drawer.
  system('', showHeader: false);

  const DestGroup(this.label, {this.showHeader = true});

  final String label;
  final bool showHeader;
}

@immutable
class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.route,
    required this.group,
    this.activeIcon,
    this.shipped = true,
    this.keywords = const [],
  });

  final String label;
  final IconData icon;

  /// Filled counterpart drawn when this destination is the current route.
  /// Falls back to [icon].
  final IconData? activeIcon;

  final String route;
  final DestGroup group;

  /// False until the doc that builds it ships. Unshipped destinations are
  /// **hidden, never shown-disabled** — there is no unlock path in a
  /// single-user app, so a greyed row teaches the user nothing.
  final bool shipped;

  /// Extra words the settings search should match. The label is always
  /// searched; these cover what the owner would actually type — "receivables"
  /// for Outstanding, "menu" for Products.
  final List<String> keywords;

  IconData get selectedIcon => activeIcon ?? icon;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (label.toLowerCase().contains(q)) return true;
    return keywords.any((k) => k.contains(q));
  }
}

/// Ordered as the drawer draws them.
const appDestinations = <AppDestination>[
  AppDestination(
    label: 'Dashboard',
    icon: Icons.insights_outlined,
    activeIcon: Icons.insights,
    route: AppRoutes.dashboard,
    group: DestGroup.primary,
    keywords: ['analytics', 'reports', 'kpi', 'insights'],
  ),

  // --- Daily ---------------------------------------------------------------
  AppDestination(
    label: 'Today',
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    route: AppRoutes.home,
    group: DestGroup.daily,
    keywords: ['home', 'orders', 'shops', 'entry'],
  ),
  AppDestination(
    label: 'Billing',
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
    route: AppRoutes.orders,
    group: DestGroup.daily,
    keywords: ['bills', 'invoice', 'totals', 'grand total'],
  ),
  AppDestination(
    label: 'Kitchen',
    icon: Icons.restaurant_outlined,
    activeIcon: Icons.restaurant,
    route: AppRoutes.kitchen,
    group: DestGroup.daily,
    keywords: ['production', 'bake', 'bake list'],
  ),

  // --- Money ---------------------------------------------------------------
  AppDestination(
    label: 'Outstanding',
    icon: Icons.account_balance_wallet_outlined,
    activeIcon: Icons.account_balance_wallet,
    route: AppRoutes.outstanding,
    group: DestGroup.money,
    keywords: ['receivables', 'owed', 'dues', 'ledger', 'balance'],
  ),
  AppDestination(
    label: 'Price Matrix',
    icon: Icons.price_change_outlined,
    activeIcon: Icons.price_change,
    route: AppRoutes.prices,
    group: DestGroup.money,
    keywords: ['prices', 'rate', 'cost', 'per shop'],
  ),

  // --- Catalogue -----------------------------------------------------------
  AppDestination(
    label: 'Shops',
    icon: Icons.store_outlined,
    activeIcon: Icons.store,
    route: AppRoutes.shops,
    group: DestGroup.catalogue,
    keywords: ['customers', 'outlets', 'stores'],
  ),
  AppDestination(
    label: 'Products',
    icon: Icons.bakery_dining_outlined,
    activeIcon: Icons.bakery_dining,
    route: AppRoutes.products,
    group: DestGroup.catalogue,
    keywords: ['items', 'catalog', 'catalogue', 'menu'],
  ),
  AppDestination(
    label: 'Categories',
    icon: Icons.category_outlined,
    activeIcon: Icons.category,
    route: AppRoutes.categories,
    group: DestGroup.catalogue,
    keywords: ['groups', 'sections'],
  ),

  // --- System --------------------------------------------------------------
  AppDestination(
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    route: AppRoutes.settings,
    group: DestGroup.system,
    keywords: ['options', 'preferences', 'config', 'backup', 'about'],
  ),

  // --- Not yet shipped -----------------------------------------------------
  // Hidden until their doc lands. Listed here so the drawer grows into its
  // final shape by flipping one flag, without another restructure.
  AppDestination(
    label: 'Auto Suggestions',
    icon: Icons.auto_awesome_outlined,
    route: '/suggestions',
    group: DestGroup.daily,
    shipped: false, // doc 15
  ),
  AppDestination(
    label: 'Weekly Report',
    icon: Icons.summarize_outlined,
    route: '/reports/weekly',
    group: DestGroup.money,
    shipped: false, // doc 16
  ),
];

/// What the drawer and the search may show. Never filter by hand at a call
/// site — an unshipped destination must not leak into the UI anywhere.
List<AppDestination> get visibleDestinations =>
    appDestinations.where((d) => d.shipped).toList();

List<AppDestination> destinationsIn(DestGroup group) =>
    visibleDestinations.where((d) => d.group == group).toList();

/// The four bottom-bar slots, in order, left to right around the centre FAB.
///
/// These are the shell's `StatefulShellBranch`es and their order is load-bearing:
/// index 0-3 here must match the branch order in `app.dart`.
const bottomBarRoutes = <String>[
  AppRoutes.home,
  AppRoutes.orders,
  AppRoutes.kitchen,
  AppRoutes.dashboard,
];

List<AppDestination> get bottomBarDestinations => [
      for (final route in bottomBarRoutes)
        appDestinations.firstWhere((d) => d.route == route),
    ];

/// The destination whose section the given location belongs to, or null.
///
/// Longest-prefix wins, so `/settings/shops/3/edit` highlights Shops rather
/// than Settings — nested routes were the thing the old hardcoded set could
/// not express at all.
AppDestination? destinationForLocation(String location) {
  AppDestination? best;
  for (final dest in visibleDestinations) {
    final isMatch = dest.route == '/'
        ? location == '/'
        : location == dest.route || location.startsWith('${dest.route}/');
    if (!isMatch) continue;
    if (best == null || dest.route.length > best.route.length) best = dest;
  }
  return best;
}
