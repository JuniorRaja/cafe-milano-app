import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_models.dart';
import '../services/category_emoji.dart';
import 'category_provider.dart';
import 'database_provider.dart';
import 'date_provider.dart';

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

// ─── Shared aggregates ──────────────────────────────────────────────────────
// getShopConcentration and getCategoryScores each feed two cards; keyed on
// range so both consumers share one execution instead of running it twice.

final shopConcentrationDataProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, DateTimeRange>((ref, range) {
  final db = ref.watch(databaseProvider);
  return db.dashboardDao.getShopConcentration(range.start, range.end);
});

final categoryScoresDataProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, DateTimeRange>((ref, range) {
  final db = ref.watch(databaseProvider);
  return db.dashboardDao.getCategoryScores(range.start, range.end);
});

// ─── Pulse Providers ────────────────────────────────────────────────────────

final todayRevenueProvider = FutureProvider<double>((ref) async {
  final db = ref.watch(databaseProvider);
  final today = ref.watch(todayProvider);
  return db.dashboardDao.getRevenueForDate(today);
});

final revenueDeltaProvider = FutureProvider<double?>((ref) async {
  final db = ref.watch(databaseProvider);
  final today = ref.watch(todayProvider);
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
  final today = ref.watch(todayProvider);
  final served = await db.dashboardDao.getShopsServedForDate(today);
  final total = await db.dashboardDao.getTotalActiveShops();
  return (served, total);
});

final pendingConfirmationsProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  final today = ref.watch(todayProvider);
  return db.dashboardDao.getPendingCountForDate(today);
});

// ─── Category Scorecards ────────────────────────────────────────────────────

final categoryScorecardsProvider =
    FutureProvider<List<CategoryScorecard>>((ref) async {
  final db = ref.watch(databaseProvider);
  final range = ref.watch(dashboardRangeProvider);
  final today = ref.watch(todayProvider);

  // Fetch active categories for name lookup
  final cats = await ref.watch(categoriesProvider.future);
  final catMap = {for (final c in cats) c.id: c.name};

  // Revenue, pieces, shops per category
  final scores = await ref.watch(categoryScoresDataProvider(range.range).future);

  // 7-day sparklines
  final sevenDaysAgo = today.subtract(const Duration(days: 6));
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

  final cats = await ref.watch(categoriesProvider.future);
  final catMap = {for (final c in cats) c.id: c.name};

  final scores = await ref.watch(categoryScoresDataProvider(range.range).future);
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

  final cats = await ref.watch(categoriesProvider.future);
  final catMap = {for (final c in cats) c.id: c.name};

  final rows = await ref.watch(shopConcentrationDataProvider(range.range).future);

  // Compute total for share %
  final totalRev =
      rows.fold<double>(0, (sum, r) => sum + (r['rev'] as double));

  // One query for every shop's category breadth instead of one per shop.
  final catIdsByShop =
      await db.dashboardDao.getShopCategoryIdsForRange(range.range.start, range.range.end);

  final List<ShopConcentrationRow> result = [];
  for (final row in rows) {
    final shopId = row['shopId'] as int;
    final rev = row['rev'] as double;
    final share = totalRev > 0 ? (rev / totalRev * 100) : 0.0;

    final catIds = catIdsByShop[shopId] ?? const [];
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

  final cats = await ref.watch(categoriesProvider.future);
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

// ─── Operational Patterns ────────────────────────────────────────────────────

/// `Map<categoryId, Map<weekday, avgPieces>>`, weekday 0 = Monday .. 6 = Sunday
/// to match the widget's day labels.
///
/// The DAO returns one row per (category, day) with that day's total. The
/// weekday and the average are derived here, in Dart, because
/// `DateTime.weekday` reads the date the app's own converter wrote — SQLite's
/// `strftime` reads epoch seconds as UTC and gets the day wrong east of
/// Greenwich. See `DashboardDao.getWeekdayHeatmap`; that is also where the bug
/// that made this card render empty for its whole life is written up.
final weekdayHeatmapProvider =
    FutureProvider<Map<int?, Map<int, double>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final today = ref.watch(todayProvider);
  final fourWeeksAgo = today.subtract(const Duration(days: 28));

  final rows = await db.dashboardDao.getWeekdayHeatmap(fourWeeksAgo);

  // Every day's total, bucketed by category and weekday, before averaging.
  // A Monday with no orders contributes nothing rather than a zero: the card
  // says "how much on a normal Monday", not "how much per calendar Monday".
  final totals = <int?, Map<int, List<int>>>{};
  for (final row in rows) {
    final catId = row['categoryId'] as int?;
    // DateTime.weekday is 1 = Monday .. 7 = Sunday.
    final weekday = (row['orderDate'] as DateTime).weekday - 1;
    final total = row['daily_total'] as int;
    totals.putIfAbsent(catId, () => {}).putIfAbsent(weekday, () => []).add(total);
  }

  return {
    for (final category in totals.entries)
      category.key: {
        for (final day in category.value.entries)
          day.key: day.value.reduce((a, b) => a + b) / day.value.length,
      },
  };
});

// ─── Attention Flags ────────────────────────────────────────────────────────

final attentionFlagsProvider =
    FutureProvider<List<AttentionFlag>>((ref) async {
  final db = ref.watch(databaseProvider);
  final range = ref.watch(dashboardRangeProvider);
  final today = ref.watch(todayProvider);

  final cats = await ref.watch(categoriesProvider.future);
  final catMap = {for (final c in cats) c.id: c.name};

  final List<AttentionFlag> flags = [];

  // 1. Declining Category — revenue down > 15% vs mirror period
  if (range.mirrorRange != null) {
    final currentRevs = await db.dashboardDao
        .getCategoryRevenuesForRange(range.range.start, range.range.end);
    final mirrorRevs = await db.dashboardDao.getCategoryRevenuesForRange(
        range.mirrorRange!.start, range.mirrorRange!.end);

    for (final entry in currentRevs.entries) {
      final catId = entry.key;
      final current = entry.value;
      final mirror = mirrorRevs[catId] ?? 0;
      if (mirror > 0) {
        final change = ((current - mirror) / mirror) * 100;
        if (change < -15) {
          final catName = catId != null ? (catMap[catId] ?? 'Others') : 'Others';
          flags.add(AttentionFlag(
            type: AttentionFlagType.decliningCategory,
            icon: '📉',
            message: '$catName down ${change.abs().toStringAsFixed(0)}%',
            detail: 'vs previous period',
          ));
        }
      }
    }
  }

  // 2. Inactive Shop — active shop with 0 orders in last 7 days
  final sevenDaysAgo = today.subtract(const Duration(days: 7));
  final inactiveIds = await db.dashboardDao.getInactiveShopIds(sevenDaysAgo);
  if (inactiveIds.isNotEmpty) {
    // Get shop names
    final allShops = await db.shopDao.watchAllShops().first;
    final shopMap = {for (final s in allShops) s.id: s.name};
    for (final id in inactiveIds.take(3)) {
      final name = shopMap[id] ?? 'Shop #$id';
      flags.add(AttentionFlag(
        type: AttentionFlagType.inactiveShop,
        icon: '🏪',
        message: '$name inactive 7+ days',
        detail: 'No orders placed recently',
      ));
    }
  }

  // 3. Concentration Risk — single shop > 25% of total revenue
  final shopConc = await ref.watch(shopConcentrationDataProvider(range.range).future);
  if (shopConc.isNotEmpty) {
    final totalRev =
        shopConc.fold<double>(0, (sum, r) => sum + (r['rev'] as double));
    if (totalRev > 0) {
      for (final shop in shopConc) {
        final share = (shop['rev'] as double) / totalRev * 100;
        if (share > 25) {
          flags.add(AttentionFlag(
            type: AttentionFlagType.concentrationRisk,
            icon: '⚖️',
            message: '${shop['shopName']} is ${share.toStringAsFixed(0)}% of revenue',
            detail: 'Diversification protects you',
          ));
        }
      }
    }
  }

  // 4. Zero Day — category with daily orders has 0 today
  final zeroDayCats = await db.dashboardDao.getZeroDayCategoryIds(today);
  for (final catId in zeroDayCats.take(2)) {
    final catName = catId != null ? (catMap[catId] ?? 'Others') : 'Others';
    flags.add(AttentionFlag(
      type: AttentionFlagType.zeroDay,
      icon: '⚠️',
      message: '$catName has 0 orders today',
      detail: 'Usually active daily',
    ));
  }

  return flags;
});
