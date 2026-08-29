import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_background.dart';
import '../floating_nav_bar.dart';
import '../ui/ui.dart';
import 'app_drawer.dart';
import 'destinations.dart';
import 'quick_action_sheet.dart';

/// The shell every branch screen is drawn inside: background, bottom bar,
/// drawer and the centre FAB.
///
/// Lifted out of `app.dart`, which was 300 lines of routing, theme and shell in
/// one file. Doc 10a took the theme out; this takes the shell, and `app.dart`
/// is left holding routing only.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// The bar and FAB belong to the four branch roots only. A pushed screen
  /// inside a branch gets neither.
  static bool showsNavBarAt(String location) =>
      bottomBarRoutes.contains(location);

  /// Opens the shell drawer from anywhere below it. Returns false when the
  /// caller is not inside the shell, so a shared header can offer the
  /// hamburger only where it would work.
  static bool openDrawer(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ShellScope>();
    if (scope == null) return false;
    scope.scaffoldKey.currentState?.openDrawer();
    return true;
  }

  static bool isInsideShell(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShellScope>() != null;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // The branch screens build their own inner Scaffold, so `Scaffold.of` from
  // inside one finds that instead of this one and the hamburger opens nothing.
  // The key is how a screen reaches *this* Scaffold specifically.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final showNavBar = AppShell.showsNavBarAt(location);

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
          _ShellScope(
            scaffoldKey: _scaffoldKey,
            child: Scaffold(
              key: _scaffoldKey,
              backgroundColor: Colors.transparent,
              drawer: const AppDrawer(),
              body: widget.navigationShell,
              bottomNavigationBar: showNavBar
                  ? FloatingNavBar(
                      selectedIndex: widget.navigationShell.currentIndex,
                      onDestinationSelected: (index) =>
                          widget.navigationShell.goBranch(
                        index,
                        initialLocation:
                            index == widget.navigationShell.currentIndex,
                      ),
                    )
                  : null,
              floatingActionButton: showNavBar
                  ? FloatingActionButton(
                      onPressed: () => showQuickActionSheet(context),
                      tooltip: 'New order, payment or shop',
                      child: const Icon(Icons.add_rounded),
                    )
                  : null,
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerDocked,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellScope extends InheritedWidget {
  const _ShellScope({required this.scaffoldKey, required super.child});

  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  bool updateShouldNotify(_ShellScope oldWidget) =>
      oldWidget.scaffoldKey != scaffoldKey;
}

/// The hamburger that opens the drawer, for the leading slot of a shell
/// screen's header.
///
/// The drawer must have a visible affordance on every screen it opens from —
/// an edge swipe alone is a feature only the person who built it knows about.
/// Outside the shell it renders nothing rather than a dead button.
class ShellDrawerButton extends StatelessWidget {
  const ShellDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppShell.isInsideShell(context)) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.menu_rounded),
      color: AppColors.textPrimary,
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      onPressed: () => AppShell.openDrawer(context),
    );
  }
}
