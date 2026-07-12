import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_models.dart';
import '../services/category_emoji.dart';
import 'database_provider.dart';

// ─── Range State ────────────────────────────────────────────────────────────

final dashboardRangeProvider =
    StateNotifierProvider<DashboardRangeNotifier, DashboardRange>((ref) {
  return DashboardRangeNotifier();
});

class DashboardRangeNotifier extends StateNotifier<DashboardRange> {
  DashboardRangeNotifier()
      : super(DashboardRange.fromPreset(DashboardPreset.thisWeek));

  void selectPreset(DashboardPreset preset) {
    state = DashboardRange.fromPreset(preset);
  }

  void selectCustomRange(DateTime start, DateTime end) {
    state = DashboardRange.fromPreset(
      DashboardPreset.custom,
      customRange: DateTimeRange(start: start, end: end),
    );
  }
}

// ─── Pulse Providers ────────────────────────────────────────────────────────

final todayRevenueProvider = FutureProvider<double>((ref) async {
  final db = ref.watch(databaseProvider);
  final today = DateTime.now();
  return db.dashboardDao.getRevenueForDate(today);
});

final revenueDeltaProvider = FutureProvider<double?>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final sameWeekdayLastWeek = today.subtract(const Duration(days: 7));

  final todayRevenue = await db.dashboardDao.getRevenueForDate(today);
  final lastWeekRevenue =
      await db.dashboardDao.getRevenueForDate(sameWeekdayLastWeek);

  if (lastWeekRevenue == 0) {
    return todayRevenue > 0 ? 100.0 : null;
  }
  return ((todayRevenue - lastWeekRevenue) / lastWeekRevenue) * 100;
});

final shopsServedTodayProvider =
    FutureProvider<(int served, int total)>((ref) async {
  final db = ref.watch(databaseProvider);
  final today = DateTime.now();
  final served = await db.dashboardDao.getShopsServedForDate(today);
  final total = await db.dashboardDao.getTotalActiveShops();
  return (served, total);
});

final pendingConfirmationsProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  final today = DateTime.now();
  return db.dashboardDao.getPendingCountForDate(today);
});

// ─── Category Scorecards ────────────────────────────────────────────────────

final categoryScorecardsProvider =
    FutureProvider<List<CategoryScorecard>>((ref) async {
  final db = ref.watch(databaseProvider);
  final range = ref.watch(dashboardRangeProvider);

  // Fetch active categories for name lookup
  final cats = await (db.categoryDao.watchActive().first);
  final catMap = {for (final c in cats) c.id: c.name};

  // Revenue, pieces, shops per category
  final scores =
      await db.dashboardDao.getCategoryScores(range.range.start, range.range.end);

  // 7-day sparklines
  final now = DateTime.now();
  final sevenDaysAgo =
      DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  final sparkRaw = await db.dashboardDao.getCategorySparklines(sevenDaysAgo);

  // Build sparkline map: categoryId → [7 ints]
  final Map<int?, List<int>> sparkMap = {};
  for (final row in sparkRaw) {
    final catId = row['categoryId'] as int?;
    sparkMap.putIfAbsent(catId, () => List.filled(7, 0));
    final date = row['orderDate'] as DateTime;
    final dayIndex = date.difference(sevenDaysAgo).inDays;
    if (dayIndex >= 0 && dayIndex < 7) {
      sparkMap[catId]![dayIndex] = row['pieces'] as int;
    }
  }

  // Star products
  final starRaw =
      await db.dashboardDao.getStarProducts(range.range.start, range.range.end);
  // Pick top-1 per category
  final Map<int?, ({String name, double rev})> starMap = {};
  for (final row in starRaw) {
    final catId = row['categoryId'] as int?;
    if (!starMap.containsKey(catId)) {
      starMap[catId] =
          (name: row['productName'] as String, rev: row['rev'] as double);
    }
  }

  // Build scorecards
  final List<CategoryScorecard> result = [];
  for (final score in scores) {
    final catId = score['categoryId'] as int?;
    final catName = catId != null ? (catMap[catId] ?? 'Others') : 'Others';
    final emoji = emojiFor(catName);
    final revenue = score['revenue'] as double;
    final star = starMap[catId];
    final starShare = (star != null && revenue > 0)
        ? (star.rev / revenue * 100)
        : 0.0;

    result.add(CategoryScorecard(
      categoryId: catId,
      categoryName: catName,
      emoji: emoji,
      revenue: revenue,
      pieces: score['pieces'] as int,
      shopCount: score['shops'] as int,
      sparklineData: sparkMap[catId] ?? List.filled(7, 0),
      starProductName: star?.name,
      starProductSharePercent: starShare,
    ));
  }

  // Sort by revenue descending
  result.sort((a, b) => b.revenue.compareTo(a.revenue));
  return result;
});

// ─── Revenue Anatomy ────────────────────────────────────────────────────────

final categoryMixProvider = FutureProvider<List<CategoryMixRow>>((ref) async {
  final db = ref.watch(databaseProvider);
  final range = ref.watch(dashboardRangeProvider);

  final cats = await db.categoryDao.watchActive().first;
  final catMap = {for (final c in cats) c.id: c.name};

  final scores =
      await db.dashboardDao.getCategoryScores(range.range.start, range.range.end);
  final totalRevenue =
      scores.fold<double>(0, (sum, s) => sum + (s['revenue'] as double));

  // Mirror period for trend
  Map<int?, double>? mirrorRevenues;
  if (range.mirrorRange != null) {
    final mirrorScores = await db.dashboardDao
        .getCategoryScores(range.mirrorRange!.start, range.mirrorRange!.end);
    mirrorRevenues = {
      for (final s in mirrorScores) s['categoryId'] as int?: s['revenue'] as double
    };
  }

  final List<CategoryMixRow> result = [];
  for (final score in scores) {
    final catId = score['categoryId'] as int?;
    final catName = catId != null ? (catMap[catId] ?? 'Others') : 'Others';
    final revenue = score['revenue'] as double;
    final share = totalRevenue > 0 ? (revenue / totalRevenue * 100) : 0.0;

    double? trend;
    if (mirrorRevenues != null) {
      final mirrorRev = mirrorRevenues[catId] ?? 0;
      if (mirrorRev > 0) {
        trend = ((revenue - mirrorRev) / mirrorRev) * 100;
      } else if (revenue > 0) {
        trend = 100.0;
      }
    }

    result.add(CategoryMixRow(
      categoryId: catId,
      categoryName: catName,
      emoji: emojiFor(catName),
      revenue: revenue,
      sharePercent: share,
      trendPercent: trend,
    ));
  }

  result.sort((a, b) => b.revenue.compareTo(a.revenue));
  return result;
});

final shopConcentrationProvider =
    FutureProvider<List<ShopConcentrationRow>>((ref) async {
  final db = ref.watch(databaseProvider);
  final range = ref.watch(dashboardRangeProvider);

  final cats = await db.categoryDao.watchActive().first;
  final catMap = {for (final c in cats) c.id: c.name};

  final rows = await db.dashboardDao
      .getShopConcentration(range.range.start, range.range.end);

  // Compute total for share %
  final totalRev =
      rows.fold<double>(0, (sum, r) => sum + (r['rev'] as double));

  final List<ShopConcentrationRow> result = [];
  for (final row in rows) {
    final shopId = row['shopId'] as int;
    final rev = row['rev'] as double;
    final share = totalRev > 0 ? (rev / totalRev * 100) : 0.0;

    // Fetch category emojis for this shop
    final catIds = await db.dashboardDao
        .getShopCategoryIds(shopId, range.range.start, range.range.end);
    final emojis = catIds
        .map((id) => emojiFor(id != null ? catMap[id] : null))
        .toList();

    result.add(ShopConcentrationRow(
      shopId: shopId,
      shopName: row['shopName'] as String,
      area: row['area'] as String?,
      revenue: rev,
      sharePercent: share,
      categoryBreadth: row['catCount'] as int,
      categoryEmojis: emojis,
    ));
  }
  return result;
});

final productLeaderboardProvider =
    FutureProvider<List<ProductLeaderRow>>((ref) async {
  final db = ref.watch(databaseProvider);
  final range = ref.watch(dashboardRangeProvider);

  final cats = await db.categoryDao.watchActive().first;
  final catMap = {for (final c in cats) c.id: c.name};

  final rows = await db.dashboardDao
      .getProductLeaderboard(range.range.start, range.range.end);

  return rows
      .map((r) => ProductLeaderRow(
            productId: r['productId'] as int,
            productName: r['productName'] as String,
            categoryId: r['categoryId'] as int?,
            categoryEmoji: emojiFor(
                r['categoryId'] != null ? catMap[r['categoryId']] : null),
            revenue: r['rev'] as double,
            qty: r['qty'] as int,
            shopCount: r['shops'] as int,
          ))
      .toList();
});

// ─── Operational Patterns (stubs — Phase C) ─────────────────────────────────

/// `Map<categoryId, Map<weekday (0=Mon..6=Sun), avgPieces>>`
final weekdayHeatmapProvider =
    FutureProvider<Map<int?, Map<int, double>>>((ref) async {
  return {};
});

/// `Map<date, Map<categoryId, revenue>>`
final stackedRevenueTrendProvider =
    FutureProvider<Map<DateTime, Map<int?, double>>>((ref) async {
  return {};
});

// ─── Attention Flags (stub — Phase C) ───────────────────────────────────────

final attentionFlagsProvider =
    FutureProvider<List<AttentionFlag>>((ref) async {
  return [];
});
