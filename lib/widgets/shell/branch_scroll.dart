import 'package:flutter/material.dart';

/// One scroll position per shell branch, reset to the top when you leave it.
///
/// `StatefulShellRoute.indexedStack` keeps every branch alive and keeps its
/// scroll position, which is right for a back press out of a pushed screen and
/// wrong for a tab switch: coming back to Orders half way down yesterday's
/// scroll is not where the day starts.
///
/// **It resets on the way out, not on the way in.** The branch is offstage by
/// then, so nothing is seen moving. Resetting when the branch appears would
/// paint one frame at the old offset before the jump lands.
///
/// The signal is [TickerMode], which `StatefulShellRoute` already wraps each
/// branch in and which notifies its dependents. `StatefulNavigationShell.of`
/// looks the same but is `findAncestorStateOfType` — no notification, so a
/// widget cannot be woken by it. `TickerMode.valuesOf` rather than
/// `TickerMode.of`, which is deprecated.
///
/// A push inside the branch does not change [TickerMode], so a back press out
/// of order entry still lands where it left the list.
class BranchScrollScope extends StatefulWidget {
  const BranchScrollScope({super.key, required this.child});

  final Widget child;

  @override
  State<BranchScrollScope> createState() => _BranchScrollScopeState();
}

class _BranchScrollScopeState extends State<BranchScrollScope> {
  final _controller = ScrollController();
  bool _wasActive = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = TickerMode.valuesOf(context).enabled;
    if (_wasActive && !isActive) _resetAfterThisFrame();
    _wasActive = isActive;
  }

  /// After the frame, never during it. This runs inside a build, and
  /// `jumpTo` notifies its listeners synchronously — a `setState` from one of
  /// them mid-build is an assertion, not a glitch.
  void _resetAfterThisFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      // Jump, never animate. By the time this branch is looked at again the
      // animation would be long over, and it costs frames on the switch.
      _controller.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController(
      controller: _controller,
      child: widget.child,
    );
  }
}
