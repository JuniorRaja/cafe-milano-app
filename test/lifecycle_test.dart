import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:milano_orders/providers/date_provider.dart';
import 'package:milano_orders/providers/order_provider.dart';
import 'package:milano_orders/providers/pending_writes.dart';
import 'package:milano_orders/providers/shop_provider.dart';
import 'package:milano_orders/screens/home/home_shops_screen.dart';
import 'package:milano_orders/theme/app_theme.dart';
import 'package:milano_orders/theme/brand_config.dart';
import 'package:milano_orders/widgets/shell/app_lifecycle_scope.dart';

/// Lifecycle-audit Phase 1, which ships inside doc 10b.
///
/// The defect these cover is real and was live: an app left open overnight
/// reported yesterday as today, on every screen, forever. The owner's phone
/// sits on a counter and the app is used at 5 a.m., so this is the normal
/// case, not an edge case.
void main() {
  final day1 = DateTime(2026, 8, 29, 22, 30);
  final day2 = DateTime(2026, 8, 30, 6, 15);

  /// Walks the real state machine. Flutter asserts on a skipped step, and
  /// `onResume` only fires on an actual transition — going straight to resumed
  /// from resumed would fire nothing and pass vacuously.
  Future<void> background(WidgetTester tester) async {
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
  }

  Future<void> backgroundAndResume(WidgetTester tester) async {
    await background(tester);
    for (final state in const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
  }

  group('midnight rollover', () {
    testWidgets('Home reports the new date after resuming across midnight',
        (tester) async {
      // This is Phase 1's done-when, and the reason Phase 1 rides in 10b.
      await withClock(Clock.fixed(day1), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeShopsProvider.overrideWith((ref) => Stream.value([])),
              orderSummariesForDateProvider
                  .overrideWith((ref, date) => Stream.value([])),
            ],
            child: MaterialApp.router(
              theme: buildAppTheme(BrandConfig.milano),
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(path: '/', builder: (_, _) => const HomeShopsScreen()),
                ],
              ),
              builder: (context, child) =>
                  AppLifecycleScope(child: child ?? const SizedBox.shrink()),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      const format = 'dd MMM yyyy, EEE';
      expect(find.text(DateFormat(format).format(day1)), findsOneWidget);

      // The phone went in a pocket at 22:30 and came back out at 06:15.
      await withClock(Clock.fixed(day2), () async {
        await backgroundAndResume(tester);
        await tester.pumpAndSettle();
      });

      expect(find.text(DateFormat(format).format(day2)), findsOneWidget);
      expect(find.text(DateFormat(format).format(day1)), findsNothing);

      // Tears the ProviderScope down inside the test. TodayNotifier holds a
      // timer scheduled for the next midnight, and the framework's
      // pending-timer check runs before addTearDown would have disposed it.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a deliberately chosen date is not dragged forward',
        (tester) async {
      // Paging to another day is a decision. Resuming must not silently undo
      // it — that would be a worse bug than the one being fixed.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await withClock(Clock.fixed(day1), () async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: AppLifecycleScope(child: SizedBox())),
          ),
        );
        await tester.pump();
      });

      final chosen = DateTime(2026, 9, 4);
      container.read(selectedDateProvider.notifier).state = chosen;

      await withClock(Clock.fixed(day2), () async {
        await backgroundAndResume(tester);
      });

      expect(container.read(todayProvider), DateTime(2026, 8, 30));
      expect(container.read(selectedDateProvider), chosen);

      // Cancels the midnight timer before the pending-timer check.
      container.dispose();
    });

    testWidgets('resuming on the same day changes nothing', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await withClock(Clock.fixed(day1), () async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: AppLifecycleScope(child: SizedBox())),
          ),
        );
        await tester.pump();

        final before = container.read(selectedDateProvider);
        await backgroundAndResume(tester);

        expect(container.read(todayProvider), DateTime(2026, 8, 29));
        expect(container.read(selectedDateProvider), before);
      });

      container.dispose();
    });

    test('todayProvider is midnight-normalised, not the wall-clock instant',
        () {
      withClock(Clock.fixed(day1), () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(container.read(todayProvider), DateTime(2026, 8, 29));
      });
    });
  });

  group('pending writes flush on pause', () {
    testWidgets('backgrounding runs every registered flush', (tester) async {
      // dispose() covers leaving the screen. Nothing covered Android
      // suspending or killing the process from paused, which is the same 500 ms
      // of typing and the same silent data loss.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var flushed = 0;
      container.read(pendingWritesProvider).register(() async => flushed++);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AppLifecycleScope(child: SizedBox())),
        ),
      );
      await tester.pump();

      await background(tester);
      await tester.pumpAndSettle();

      expect(flushed, 1);
      container.dispose();
    });

    test('unregistering stops a disposed screen being flushed', () async {
      final pending = PendingWrites();
      var flushed = 0;
      final unregister = pending.register(() async => flushed++);

      expect(pending.pendingCount, 1);
      unregister();
      expect(pending.pendingCount, 0);

      await pending.flushAll();
      expect(flushed, 0);
    });

    test('one failing flush does not stop the others', () async {
      // This runs while the app is being suspended. There is nobody left to
      // show an error to, and a throw here would strand the remaining writes.
      final pending = PendingWrites();
      var second = 0;
      pending.register(() async => throw StateError('disk full'));
      pending.register(() async => second++);

      await pending.flushAll();
      expect(second, 1);
    });
  });

}
