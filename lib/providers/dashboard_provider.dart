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
  ref.watch(dashboardRangeProvider); // dependency for refresh
  final today = DateTime.now();
  return db.dashboardDao.getRevenueForDate(today);
});

final revenueDeltaProvider = FutureProvider<double?>((ref) async {
  final db = ref.watch(databaseProvider);
  ref.watch(dashboardRangeProvider); // dependency for refresh
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
  ref.watch(dashboardRangeProvider); // dependency for refresh
  final today = DateTime.now();
  final served = await db.dashboardDao.getShopsServedForDate(today);
  final total = await db.dashboardDao.getTotalActiveShops();
  return (served, total);
});

final pendingConfirmationsProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  ref.watch(dashboardRangeProvider); // dependency for refresh
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

// ─── Operational Patterns ────────────────────────────────────────────────────

/// `Map<categoryId, Map<weekday (0=Sun..6=Sat → remapped to 0=Mon..6=Sun), avgPieces>>`
final weekdayHeatmapProvider =
    FutureProvider<Map<int?, Map<int, double>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final fourWeeksAgo =
      DateTime(now.year, now.month, now.day).subtract(const Duration(days: 28));

  final rows = await db.dashboardDao.getWeekdayHeatmap(fourWeeksAgo);

  // SQLite strftime('%w') → 0=Sunday..6=Saturday
  // We want 0=Monday..6=Sunday
  int remapWeekday(int sqliteWeekday) {
    // 0(Sun)→6, 1(Mon)→0, 2(Tue)→1, ... 6(Sat)→5
    return (sqliteWeekday + 6) % 7;
  }

  final Map<int?, Map<int, double>> result = {};
  for (final row in rows) {
    final catId = row['categoryId'] as int?;
    final weekday = remapWeekday(row['weekday'] as int);
    final avg = row['avg_pieces'] as double;
    result.putIfAbsent(catId, () => {});
    result[catId]![weekday] = avg;
  }
  return result;
});

// ─── Attention Flags ────────────────────────────────────────────────────────

final attentionFlagsProvider =
    FutureProvider<List<AttentionFlag>>((ref) async {
  final db = ref.watch(databaseProvider);
  final range = ref.watch(dashboardRangeProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final cats = await db.categoryDao.watchActive().first;
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
  final shopConc = await db.dashboardDao
      .getShopConcentration(range.range.start, range.range.end);
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
