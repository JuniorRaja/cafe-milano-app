/// The window the Ledger totals billing and collection over.
///
/// The screen was fixed at 30 days, with a doc comment defending it: a range
/// picker here would duplicate the dashboard's, and the question is "where do I
/// stand right now". The owner overruled that on the device pass. This is a
/// separate setting from the dashboard's on purpose — changing the period on
/// one screen must not move the other.
enum LedgerPeriod {
  /// The default here. Every bill and every payment ever recorded.
  allTime('All time'),
  thisMonth('This month'),
  lastMonth('Last month'),
  last30('Last 30 days'),
  last90('Last 90 days');

  const LedgerPeriod(this.label);

  final String label;

  /// The inclusive day range to total over, given today.
  ///
  /// `last30` is today plus the 29 days before it, which is thirty days. The
  /// fixed window this replaced subtracted 30 and counted thirty-one.
  ({DateTime from, DateTime to}) rangeOn(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    return switch (this) {
      // Before the first Android release, so it cannot cut anything off. Not
      // `DateTime(0)`, which drift would store as a negative epoch second.
      LedgerPeriod.allTime => (from: DateTime(1970), to: day),
      LedgerPeriod.thisMonth => (
          from: DateTime(day.year, day.month),
          to: day,
        ),
      LedgerPeriod.lastMonth => (
          from: DateTime(day.year, day.month - 1),
          // Day zero of this month is the last day of the previous one, and it
          // handles December and leap years without a table.
          to: DateTime(day.year, day.month, 0),
        ),
      LedgerPeriod.last30 => (
          from: day.subtract(const Duration(days: 29)),
          to: day,
        ),
      LedgerPeriod.last90 => (
          from: day.subtract(const Duration(days: 89)),
          to: day,
        ),
    };
  }
}

/// How the "Who owes" list is ordered.
enum OwedSort {
  /// Biggest debt first. What the screen is usually opened for.
  amount('Amount'),

  /// Alphabetical, for finding one shop you have in mind.
  name('Name');

  const OwedSort(this.label);

  final String label;
}
