import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Midnight-normalised "today" — the single source for every provider that
/// means *today* rather than the selected date.
///
/// It corrects itself two ways, because either one alone leaves a real hole.
/// The timer covers an app left foregrounded overnight — a phone on a kitchen
/// counter at 5 a.m. is the normal case here, not the edge case. The resume
/// hook in `AppLifecycleScope` covers an app that was backgrounded instead,
/// where the timer does not reliably fire. Before both, an app left open
/// overnight reported yesterday as today, on every screen, forever.
///
/// The read signature is unchanged: `ref.watch(todayProvider)` still yields a
/// `DateTime`, and `ref.invalidate(todayProvider)` still forces a re-derive.
final todayProvider = NotifierProvider<TodayNotifier, DateTime>(
  TodayNotifier.new,
);

DateTime _startOfDay(DateTime at) => DateTime(at.year, at.month, at.day);

class TodayNotifier extends Notifier<DateTime> {
  Timer? _rollover;

  @override
  DateTime build() {
    ref.onDispose(() => _rollover?.cancel());
    _scheduleRollover();
    return _startOfDay(DateTime.now());
  }

  /// Re-reads the wall clock. Safe to call at any time — it is a no-op unless
  /// the date actually moved, so it never causes a spurious rebuild.
  void refresh() {
    final now = _startOfDay(DateTime.now());
    if (now != state) state = now;
    _scheduleRollover();
  }

  void _scheduleRollover() {
    _rollover?.cancel();
    final now = DateTime.now();
    final nextMidnight = _startOfDay(now).add(const Duration(days: 1));
    // One second past midnight, not exactly on it: Timer fires on elapsed
    // duration, and landing a millisecond early would read the old date and
    // reschedule a zero-length timer.
    final delay = nextMidnight.difference(now) + const Duration(seconds: 1);
    _rollover = Timer(delay, refresh);
  }
}

/// The date the user is looking at. Distinct from [todayProvider]: the owner
/// routinely enters tomorrow's orders tonight.
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return _startOfDay(DateTime.now());
});
