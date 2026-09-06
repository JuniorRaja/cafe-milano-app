import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/date_provider.dart';
import '../../providers/pending_writes.dart';

/// The app's single [AppLifecycleListener].
///
/// One listener at the root, not one per screen. Doc 14's biometric gate hangs
/// off this same object later, which is the second reason to put it in
/// properly now rather than sprinkling `didChangeAppLifecycleState` overrides
/// through the screens that happen to care.
///
/// It closes a live defect: an app left open overnight reported yesterday as
/// today, on every screen, forever. `todayProvider` also carries a midnight
/// timer for the foregrounded case; this covers the backgrounded one, where
/// that timer cannot be relied on to fire.
class AppLifecycleScope extends ConsumerStatefulWidget {
  const AppLifecycleScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleScope> createState() => _AppLifecycleScopeState();
}

class _AppLifecycleScopeState extends ConsumerState<AppLifecycleScope> {
  late final AppLifecycleListener _listener;

  /// The date the app was last known to be showing.
  ///
  /// Tracked here rather than re-read from [todayProvider] on resume, and the
  /// difference is not cosmetic. `todayProvider` is lazy: if nothing has
  /// watched it yet, reading it at resume builds it from the clock *as it is
  /// now*, so "did the date change while we were away?" compares the new day
  /// against itself and is always false. The rollover would then never fire on
  /// the screens that need it most — Home watches the selected date, not this.
  late DateTime _lastKnownToday;

  @override
  void initState() {
    super.initState();
    // Reading it here also starts its midnight timer at launch rather than
    // whenever some screen first happens to want today's date.
    _lastKnownToday = ref.read(todayProvider);
    _listener = AppLifecycleListener(
      onResume: _onResume,
      onPause: _onPause,
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  void _onResume() {
    final before = _lastKnownToday;
    ref.read(todayProvider.notifier).refresh();
    final after = ref.read(todayProvider);
    _lastKnownToday = after;
    if (before == after) return;

    // The date rolled over while the app was away. The *selected* date follows
    // only because it was still sitting on the old today — if the owner had
    // deliberately paged to another day before backgrounding, that choice is
    // theirs and is left alone.
    if (ref.read(selectedDateProvider) == before) {
      ref.read(selectedDateProvider.notifier).state = after;
    }
  }

  void _onPause() {
    // Android may suspend or kill the process from here without ever calling
    // dispose, so a debounced order-entry save has to go now.
    ref.read(pendingWritesProvider).flushAll().ignore();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
