import 'package:intl/intl.dart';

/// `Today`, `Tomorrow`, `This Fri`, `Next Tue`, `Last Tue` — or null.
///
/// Null means there is no useful word for this date, and the caller should show
/// nothing rather than something. The date itself is always on screen; this is
/// the line under it, and `12 Sep` under `12 Sep 2026, Sat` is noise.
///
/// One function, called by the one `DateSelector` that Orders, Kitchen and
/// Billing all use. Three copies of a date ladder is three chances to disagree
/// about what "next week" means.
///
/// Weeks start on Monday, matching the dashboard heatmap's day labels.
String? relativeDayLabel(DateTime date, {required DateTime today}) {
  final days = _dayNumber(date) - _dayNumber(today);
  switch (days) {
    case 0:
      return 'Today';
    case 1:
      return 'Tomorrow';
    case -1:
      return 'Yesterday';
  }

  // Calendar weeks, not seven-day windows. On a Friday, "next Monday" is three
  // days away and "this Monday" was four days ago; a rolling window would call
  // both of them the same thing.
  final weeks = (_weekStart(date) - _weekStart(today)) ~/ 7;
  final weekday = DateFormat('EEE').format(date);
  return switch (weeks) {
    0 => 'This $weekday',
    1 => 'Next $weekday',
    -1 => 'Last $weekday',
    _ => null,
  };
}

/// Whole days since the epoch.
///
/// Built in UTC on purpose. `DateTime.difference` between two local midnights
/// is 23 or 25 hours across a daylight-saving boundary, and `inDays` truncates
/// that to zero — so a date one day away would read as today.
int _dayNumber(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;

/// The day number of the Monday that starts this date's week.
int _weekStart(DateTime date) => _dayNumber(date) - (date.weekday - 1);
