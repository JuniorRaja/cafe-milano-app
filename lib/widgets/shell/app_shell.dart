import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';

import '../floating_nav_bar.dart';
import '../ui/ui.dart';
import 'app_drawer.dart';
import 'destinations.dart';

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

  /// What a shell screen must leave at the bottom of its scroll view.
  ///
  /// The bar used to sit in `Scaffold.bottomNavigationBar`, which insets the
  /// body, so screens got this space for free and then guessed at a little
  /// more — 96 here, 100 there, `AppSpace.s6 * 3` somewhere else. The bar now
  /// floats over the body, so the space is theirs to leave, and it is one
  /// number: the bar's own height and margins, plus the gesture inset it sits
  /// above, plus a gap so the last row is not tucked under its edge.
  static double bottomInset(BuildContext context) =>
      FloatingNavBar.height +
      AppSpace.s2 * 2 +
      AppSpace.s3 +
      MediaQuery.paddingOf(context).bottom;

  /// Opens the shell drawer from anywhere below it. Returns false when the
  /// caller is not inside the shell, so a shared header can offer the
  /// hamburger only where it would work.
  ///
  /// Reads the scope without depending on it: this runs from a button
  /// callback, not from build, and registering a dependency outside build is
  /// both meaningless and an assertion in debug.
  static bool openDrawer(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_ShellScope>();
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

  bool _barVisible = true;

  /// Hide on the way down, show on the way up, show at the top.
  ///
  /// `idle` deliberately does **not** show the bar on its own. Scrolling down
  /// and lifting your finger would bring it straight back, which is a flicker
  /// rather than a feature — so at rest it stays where the last gesture left
  /// it, unless that rest is at the top of the list.
  bool _onUserScroll(UserScrollNotification notification) {
    final metrics = notification.metrics;
    // Horizontal strips — the date-range pills, the category chips — are
    // scroll views too, and swiping them is not a scroll down the page.
    if (metrics.axis != Axis.vertical) return false;

    final atTop = metrics.pixels <= metrics.minScrollExtent;
    // A list that does not scroll cannot ask for more room than it has.
    final scrolls = metrics.maxScrollExtent > 0;

    final next = switch (notification.direction) {
      ScrollDirection.reverse => !scrolls,
      ScrollDirection.forward => true,
      ScrollDirection.idle => atTop || _barVisible,
    };

    if (next != _barVisible) setState(() => _barVisible = next);
    // Never swallow it: other listeners, and the screens themselves, still
    // want to know.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final showNavBar = AppShell.showsNavBarAt(location);

    // The background is no longer painted here. It is painted once for the
    // whole app, in `app.dart`'s `MaterialApp.builder`, because only the five
    // shell branches ever reached this widget: every pushed screen — order
    // entry, the ledger, the masters, settings — drew on flat cream, which is
    // the inconsistency the device pass found. One layer above the router
    // covers both, and is built once for the process rather than on every
    // shell rebuild.
    //
    // The reason it had to sit outside the Scaffold still holds up there.
    // `bottomNavigationBar` insets the body, so a body-level background is
    // laid out ~80px shorter on shell routes than on sub-routes. `BoxFit.cover`
    // recomputes its crop against that shorter box, so popping back from a
    // sub-route visibly rescaled the artwork mid-transition.

    // Reduced motion keeps the bar where it is. A control that disappears is
    // the kind of movement the setting exists to switch off, and hiding it
    // without the slide would be worse, not better.
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final hidden = showNavBar && !_barVisible && !reducedMotion;

    // The bar is no longer in `bottomNavigationBar`. That slot insets the
    // body, so animating the bar's height would relayout every screen on every
    // frame of the slide — the same reason the background had to leave the
    // Scaffold. It is a bottom-positioned overlay now, and shell screens leave
    // room for it themselves with `AppShell.bottomInset`.
    return _ShellScope(
      scaffoldKey: _scaffoldKey,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        drawer: const AppDrawer(),
        body: Stack(
          children: [
            NotificationListener<UserScrollNotification>(
              onNotification: _onUserScroll,
              child: widget.navigationShell,
            ),
            if (showNavBar)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedSlide(
                  offset: Offset(0, hidden ? 1 : 0),
                  duration: reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: FloatingNavBar(
                    selectedIndex: widget.navigationShell.currentIndex,
                    onDestinationSelected: (index) =>
                        widget.navigationShell.goBranch(
                      index,
                      initialLocation:
                          index == widget.navigationShell.currentIndex,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
