// `refreshDashboard` is a hand-written list of invalidations, and the defect
// doc 10c names is that a provider added later and not appended to it stops
// refreshing without saying so.
//
// The list cannot be derived at runtime — Riverpod has no "invalidate
// everything in this library" — so it is derived here instead, from the
// source, and this test fails the moment the two disagree.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refreshDashboard invalidates every provider in its own file', () {
    final source = File('lib/providers/dashboard_provider.dart')
        .readAsStringSync();

    final declared = RegExp(r'^final (\w+Provider)\b', multiLine: true)
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toSet();

    final body = source.substring(source.indexOf('void refreshDashboard('));
    final invalidated = RegExp(r'ref\.invalidate\((\w+)\)')
        .allMatches(body)
        .map((m) => m.group(1)!)
        .toSet();

    // The range holds the period the owner picked. Invalidating it would reset
    // that, which is a bug rather than a refresh — so it is the one exception.
    final expected = declared.difference({'dashboardRangeProvider'});

    expect(
      expected.difference(invalidated),
      isEmpty,
      reason: 'these providers were added to dashboard_provider.dart but not '
          'to refreshDashboard, so the refresh button silently skips them',
    );
  });
}
