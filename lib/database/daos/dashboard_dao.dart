part of '../app_database.dart';

@DriftAccessor(tables: [DailyOrders, OrderLines, Products, Categories, Shops])
class DashboardDao extends DatabaseAccessor<AppDatabase>
    with _$DashboardDaoMixin {
  DashboardDao(super.db);

  // ─── Pulse ──────────────────────────────────────────────────────────────

  /// Total revenue for a given date.
  Future<double> getRevenueForDate(DateTime date) async {
    // Stub — Phase B
    return 0.0;
  }

  /// Count of distinct shops that have orders on [date].
  Future<int> getShopsServedForDate(DateTime date) async {
    // Stub — Phase B
    return 0;
  }

  /// Count of total active shops.
  Future<int> getTotalActiveShops() async {
    // Stub — Phase B
    return 0;
  }

  /// Count of unconfirmed orders for [date].
  Future<int> getPendingCountForDate(DateTime date) async {
    // Stub — Phase B
    return 0;
  }

  // ─── Category Scorecards ────────────────────────────────────────────────

  /// Revenue, pieces, shopCount per category for a date range.
  Future<List<Map<String, dynamic>>> getCategoryScores(
      DateTime start, DateTime end) async {
    // Stub — Phase B
    return [];
  }

  /// 7-day sparklines for all categories (daily piece totals).
  Future<List<Map<String, dynamic>>> getCategorySparklines(
      DateTime sevenDaysAgo) async {
    // Stub — Phase B
    return [];
  }

  /// Top product per category by revenue in range.
  Future<List<Map<String, dynamic>>> getStarProducts(
      DateTime start, DateTime end) async {
    // Stub — Phase B
    return [];
  }

  // ─── Revenue Anatomy ───────────────────────────────────────────────────

  /// Top shops by revenue with category breadth.
  Future<List<Map<String, dynamic>>> getShopConcentration(
      DateTime start, DateTime end,
      {int limit = 5}) async {
    // Stub — Phase B
    return [];
  }

  /// Top products by revenue.
  Future<List<Map<String, dynamic>>> getProductLeaderboard(
      DateTime start, DateTime end,
      {int limit = 10}) async {
    // Stub — Phase B
    return [];
  }

  // ─── Operational Patterns ──────────────────────────────────────────────

  /// Weekday heatmap: avg pieces per category per weekday (last 4 weeks).
  Future<List<Map<String, dynamic>>> getWeekdayHeatmap(
      DateTime fourWeeksAgo) async {
    // Stub — Phase C
    return [];
  }

  /// Stacked revenue trend: daily revenue per category (30 days).
  Future<List<Map<String, dynamic>>> getStackedTrend(
      DateTime thirtyDaysAgo) async {
    // Stub — Phase C
    return [];
  }

  // ─── Attention Flags ───────────────────────────────────────────────────

  /// Active shops with no orders in the last 7 days.
  Future<List<int>> getInactiveShopIds(DateTime sevenDaysAgo) async {
    // Stub — Phase C
    return [];
  }
}
