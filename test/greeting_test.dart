// The greeting on the Dashboard header.
//
// It existed, and commit `ddd08d8` deleted it along with the thing that was
// actually wrong: a hardcoded `['Mohan', 'JMR']` picked by `Random()` at
// library load. The owner asked for it back on the device pass, and asked for
// it without a name. See docs/features/10b-device-pass.md, C1.
//
// Every boundary is asserted rather than sampled. A greeting that says "Good
// evening" at breakfast is the only way this can be wrong, and it is wrong on
// the first screen of the app.
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milano_orders/utils/greeting.dart';

void main() {
  DateTime at(int hour) => DateTime(2026, 9, 5, hour, 30);

  group('greetingFor', () {
    test('morning runs from 05:00 to 11:59', () {
      expect(greetingFor(DateTime(2026, 9, 5, 5)), 'Good morning');
      expect(greetingFor(at(9)), 'Good morning');
      expect(greetingFor(DateTime(2026, 9, 5, 11, 59)), 'Good morning');
    });

    test('afternoon runs from 12:00 to 16:59', () {
      expect(greetingFor(DateTime(2026, 9, 5, 12)), 'Good afternoon');
      expect(greetingFor(at(15)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 9, 5, 16, 59)), 'Good afternoon');
    });

    test('evening runs from 17:00 through the small hours', () {
      expect(greetingFor(DateTime(2026, 9, 5, 17)), 'Good evening');
      expect(greetingFor(at(22)), 'Good evening');
      expect(greetingFor(DateTime(2026, 9, 5, 0)), 'Good evening');
      // 04:59 is still the night before. The bake starts at five.
      expect(greetingFor(DateTime(2026, 9, 5, 4, 59)), 'Good evening');
    });

    test('reads the wall clock through package:clock, not DateTime.now', () {
      withClock(Clock.fixed(at(6)), () {
        expect(greetingFor(), 'Good morning');
      });
      withClock(Clock.fixed(at(20)), () {
        expect(greetingFor(), 'Good evening');
      });
    });
  });
}
