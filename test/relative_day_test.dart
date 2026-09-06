// The word under the date on Orders, Kitchen and Billing.
//
// Every boundary is asserted rather than sampled. A selector that says "Today"
// about yesterday is wrong on the screen the owner enters the day's orders
// from. See docs/features/10b-device-pass.md, J2.
import 'package:flutter_test/flutter_test.dart';
import 'package:milano_orders/utils/relative_day.dart';

void main() {
  // A Saturday. Its week is Mon 31 Aug — Sun 6 Sep.
  final saturday = DateTime(2026, 9, 5);

  String? label(DateTime date, {DateTime? today}) =>
      relativeDayLabel(date, today: today ?? saturday);

  group('relativeDayLabel', () {
    test('the three days with names of their own', () {
      expect(label(DateTime(2026, 9, 5)), 'Today');
      expect(label(DateTime(2026, 9, 6)), 'Tomorrow');
      expect(label(DateTime(2026, 9, 4)), 'Yesterday');
    });

    test('the rest of this calendar week', () {
      expect(label(DateTime(2026, 8, 31)), 'This Mon');
      expect(label(DateTime(2026, 9, 2)), 'This Wed');
      // Sunday the 6th is tomorrow, so it keeps the better word.
      expect(label(DateTime(2026, 9, 6)), 'Tomorrow');
    });

    test('the week either side', () {
      expect(label(DateTime(2026, 9, 8)), 'Next Tue');
      expect(label(DateTime(2026, 9, 13)), 'Next Sun');
      expect(label(DateTime(2026, 8, 25)), 'Last Tue');
      expect(label(DateTime(2026, 8, 30)), 'Last Sun');
    });

    test('weeks are calendar weeks, not seven-day windows', () {
      // From Saturday the 5th, Monday the 7th is two days away and Monday the
      // 31st was five days ago. A rolling window would call them the same.
      expect(label(DateTime(2026, 9, 7)), 'Next Mon');
      expect(label(DateTime(2026, 8, 31)), 'This Mon');
    });

    test('weeks start on Monday, so Sunday closes one', () {
      final sunday = DateTime(2026, 9, 6);
      // Monday the 31st is still *this* week from Sunday the 6th.
      expect(label(DateTime(2026, 8, 31), today: sunday), 'This Mon');
      // Monday the 7th is the next one.
      expect(label(DateTime(2026, 9, 7), today: sunday), 'Tomorrow');
      expect(label(DateTime(2026, 9, 8), today: sunday), 'Next Tue');
    });

    test('anything further out has no word, and says nothing', () {
      // Null, not `12 Sep`. The date is already the line above it.
      expect(label(DateTime(2026, 9, 15)), isNull);
      expect(label(DateTime(2026, 8, 20)), isNull);
      expect(label(DateTime(2025, 9, 5)), isNull);
    });

    test('the ladder works across a month and a year boundary', () {
      final newYearsEve = DateTime(2025, 12, 31); // a Wednesday
      expect(label(DateTime(2026, 1, 1), today: newYearsEve), 'Tomorrow');
      expect(label(DateTime(2026, 1, 2), today: newYearsEve), 'This Fri');
      expect(label(DateTime(2026, 1, 6), today: newYearsEve), 'Next Tue');
    });

    test('the time of day on either side is ignored', () {
      expect(
        relativeDayLabel(
          DateTime(2026, 9, 6, 0, 5),
          today: DateTime(2026, 9, 5, 23, 55),
        ),
        'Tomorrow',
      );
    });
  });
}
