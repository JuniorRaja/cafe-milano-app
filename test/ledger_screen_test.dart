// The Ledger screen — the one that used to be called Finances.
//
// Two rules worth holding. The period control is **this screen's**, not the
// dashboard's, so the two cannot move each other. And the period filters the
// billed/collected band only: what you are owed is a balance as of right now
// and does not become a different number because you asked about last month.
// See docs/features/10b-device-pass.md, H1-H4.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/providers/date_provider.dart';
import 'package:milano_orders/providers/ledger_provider.dart';
import 'package:milano_orders/screens/finances/finances_screen.dart';
import 'package:milano_orders/theme/app_theme.dart';
import 'package:milano_orders/theme/brand_config.dart';
import 'package:milano_orders/utils/ledger_period.dart';

void main() {
  ShopOutstanding owed(int id, String name, double amount) =>
      ShopOutstanding(shopId: id, shopName: name, outstanding: amount);

  group('LedgerPeriod', () {
    final today = DateTime(2026, 9, 5);

    test('all time starts before any record could exist', () {
      final range = LedgerPeriod.allTime.rangeOn(today);
      expect(range.from, DateTime(1970));
      expect(range.to, today);
    });

    test('last 30 days is thirty days, today included', () {
      final range = LedgerPeriod.last30.rangeOn(today);
      // 7 Aug through 5 Sep inclusive. The fixed window this replaced
      // subtracted 30 and counted thirty-one.
      expect(range.from, DateTime(2026, 8, 7));
      expect(range.to.difference(range.from).inDays, 29);
    });

    test('this month starts on the first', () {
      expect(LedgerPeriod.thisMonth.rangeOn(today).from, DateTime(2026, 9));
    });

    test('last month is a closed month, not a rolling window', () {
      final range = LedgerPeriod.lastMonth.rangeOn(today);
      expect(range.from, DateTime(2026, 8));
      expect(range.to, DateTime(2026, 8, 31));
    });

    test('last month crosses a year boundary', () {
      final range = LedgerPeriod.lastMonth.rangeOn(DateTime(2026, 1, 9));
      expect(range.from, DateTime(2025, 12));
      expect(range.to, DateTime(2025, 12, 31));
    });

    test('last month knows February in a leap year', () {
      final range = LedgerPeriod.lastMonth.rangeOn(DateTime(2028, 3, 4));
      expect(range.to, DateTime(2028, 2, 29));
    });

    test('the time of day today does not shift the range', () {
      final range = LedgerPeriod.thisMonth.rangeOn(DateTime(2026, 9, 5, 23, 40));
      expect(range.to, DateTime(2026, 9, 5));
    });
  });

  group('the Ledger screen', () {
    final today = DateTime(2026, 9, 5);

    /// Records every range the screen asks for, so a test can assert which
    /// window the period control actually selected.
    late List<({DateTime from, DateTime to})> asked;

    Widget buildLedger({
      List<ShopOutstanding> shops = const [],
      OutstandingSummary summary = OutstandingSummary.empty,
      PeriodMoney allTime = const PeriodMoney(billed: 900, collected: 400),
      PeriodMoney other = const PeriodMoney(billed: 100, collected: 60),
    }) {
      asked = [];
      return ProviderScope(
        overrides: [
          todayProvider.overrideWith(() => _FixedToday(today)),
          outstandingSummaryProvider.overrideWith((ref) => Stream.value(summary)),
          outstandingByShopProvider.overrideWith((ref) => Stream.value(shops)),
          periodMoneyProvider.overrideWith((ref, range) {
            asked.add(range);
            return Stream.value(
              range.from == DateTime(1970) ? allTime : other,
            );
          }),
        ],
        child: MaterialApp(
          theme: buildAppTheme(BrandConfig.milano),
          home: const FinancesScreen(),
        ),
      );
    }

    testWidgets('is called Ledger, and opens on All time', (tester) async {
      await tester.pumpWidget(buildLedger());
      await tester.pumpAndSettle();

      expect(find.text('Ledger'), findsOneWidget);
      expect(find.text('Finances'), findsNothing);
      expect(find.text('All time'), findsOneWidget);
      expect(asked.single.from, DateTime(1970));
    });

    testWidgets('the tertiary caption over the background art is gone',
        (tester) async {
      await tester.pumpWidget(buildLedger());
      await tester.pumpAndSettle();

      expect(find.text('Billed against collected'), findsNothing);
      expect(find.text('Last 30 days'), findsNothing);
      // The three figures label themselves instead.
      expect(find.text('billed'), findsOneWidget);
      expect(find.text('collected'), findsOneWidget);
    });

    testWidgets('changing the period re-asks for that window', (tester) async {
      await tester.pumpWidget(buildLedger());
      await tester.pumpAndSettle();
      expect(find.text('₹900'), findsOneWidget);

      await tester.tap(find.text('All time'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(
          CheckedPopupMenuItem<LedgerPeriod>, 'Last 30 days'));
      await tester.pumpAndSettle();

      expect(asked.last.from, DateTime(2026, 8, 7));
      expect(find.text('₹100'), findsOneWidget);
    });

    testWidgets('the period leaves the outstanding hero alone', (tester) async {
      await tester.pumpWidget(buildLedger(
        summary: const OutstandingSummary(total: 7500, shopCount: 3),
      ));
      await tester.pumpAndSettle();

      // HeroStatCard renders its caption uppercase.
      expect(find.text('OUTSTANDING RIGHT NOW'), findsOneWidget);
      expect(find.text('₹7,500'), findsOneWidget);

      await tester.tap(find.text('All time'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(
          CheckedPopupMenuItem<LedgerPeriod>, 'This month'));
      await tester.pumpAndSettle();

      // A balance is not a period figure.
      expect(find.text('₹7,500'), findsOneWidget);
    });

    testWidgets('sorting by name puts a small debt above a big one',
        (tester) async {
      await tester.pumpWidget(buildLedger(shops: [
        owed(1, 'Zebra Bakery', 900),
        owed(2, 'Anna Stores', 100),
      ]));
      await tester.pumpAndSettle();

      Offset yOf(String name) => tester.getTopLeft(find.text(name));

      // By amount: Zebra owes more, so Zebra is first.
      expect(yOf('Zebra Bakery').dy, lessThan(yOf('Anna Stores').dy));

      await tester.tap(find.text('Amount'));
      await tester.pumpAndSettle();
      await tester.tap(
          find.widgetWithText(CheckedPopupMenuItem<OwedSort>, 'Name'));
      await tester.pumpAndSettle();

      expect(yOf('Anna Stores').dy, lessThan(yOf('Zebra Bakery').dy));
    });
  });
}

class _FixedToday extends TodayNotifier {
  _FixedToday(this.value);

  final DateTime value;

  @override
  DateTime build() => value;
}
