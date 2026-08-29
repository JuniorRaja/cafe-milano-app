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

  @override
  void initState() {
    super.initState();
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
    final before = ref.read(todayProvider);
    ref.read(todayProvider.notifier).refresh();
    final after = ref.read(todayProvider);
    if (before == after) return;

    // The date rolled over while the app was away. The *selected* date follows
    // only because it was still sitting on the old today — if the owner had
    // deliberately paged to another day before backgrounding, that choice is
    // theirs and is left alone.
    final selected = ref.read(selectedDateProvider);
    if (selected == before) {
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
