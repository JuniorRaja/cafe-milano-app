import 'package:flutter/material.dart';

// ─── Date Range ─────────────────────────────────────────────────────────────

enum DashboardPreset {
  today,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  last90,
  custom,
}

class DashboardRange {
  final DashboardPreset preset;
  final DateTimeRange range;
  final DateTimeRange? mirrorRange;

  const DashboardRange({
    required this.preset,
    required this.range,
    this.mirrorRange,
  });

  /// Resolves a preset to concrete date ranges.
  factory DashboardRange.fromPreset(DashboardPreset preset, {DateTimeRange? customRange}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (preset) {
      case DashboardPreset.today:
        final sameWeekdayLastWeek = today.subtract(const Duration(days: 7));
        return DashboardRange(
          preset: preset,
          range: DateTimeRange(start: today, end: today),
          mirrorRange: DateTimeRange(start: sameWeekdayLastWeek, end: sameWeekdayLastWeek),
        );

      case DashboardPreset.thisWeek:
        // Monday → today
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final daysFromMonday = today.difference(monday).inDays;
        final prevMonday = monday.subtract(const Duration(days: 7));
        final prevSameDay = prevMonday.add(Duration(days: daysFromMonday));
        return DashboardRange(
          preset: preset,
          range: DateTimeRange(start: monday, end: today),
          mirrorRange: DateTimeRange(start: prevMonday, end: prevSameDay),
        );

      case DashboardPreset.lastWeek:
        final thisMonday = today.subtract(Duration(days: today.weekday - 1));
        final lastMonday = thisMonday.subtract(const Duration(days: 7));
        final lastSunday = thisMonday.subtract(const Duration(days: 1));
        final prevMonday = lastMonday.subtract(const Duration(days: 7));
        final prevSunday = lastMonday.subtract(const Duration(days: 1));
        return DashboardRange(
          preset: preset,
          range: DateTimeRange(start: lastMonday, end: lastSunday),
          mirrorRange: DateTimeRange(start: prevMonday, end: prevSunday),
        );

      case DashboardPreset.thisMonth:
        final firstOfMonth = DateTime(today.year, today.month, 1);
        final dayOfMonth = today.day;
        final prevMonth = DateTime(today.year, today.month - 1, 1);
        final prevSameDay = DateTime(today.year, today.month - 1, dayOfMonth);
        return DashboardRange(
          preset: preset,
          range: DateTimeRange(start: firstOfMonth, end: today),
          mirrorRange: DateTimeRange(start: prevMonth, end: prevSameDay),
        );

      case DashboardPreset.lastMonth:
        final firstOfThisMonth = DateTime(today.year, today.month, 1);
        final lastDayPrevMonth = firstOfThisMonth.subtract(const Duration(days: 1));
        final firstOfPrevMonth = DateTime(lastDayPrevMonth.year, lastDayPrevMonth.month, 1);
        final twoMonthsAgoEnd = firstOfPrevMonth.subtract(const Duration(days: 1));
        final twoMonthsAgoStart = DateTime(twoMonthsAgoEnd.year, twoMonthsAgoEnd.month, 1);
        return DashboardRange(
          preset: preset,
          range: DateTimeRange(start: firstOfPrevMonth, end: lastDayPrevMonth),
          mirrorRange: DateTimeRange(start: twoMonthsAgoStart, end: twoMonthsAgoEnd),
        );

      case DashboardPreset.last90:
        final start = today.subtract(const Duration(days: 89));
        final mirrorEnd = start.subtract(const Duration(days: 1));
        final mirrorStart = mirrorEnd.subtract(const Duration(days: 89));
        return DashboardRange(
          preset: preset,
          range: DateTimeRange(start: start, end: today),
          mirrorRange: DateTimeRange(start: mirrorStart, end: mirrorEnd),
        );

      case DashboardPreset.custom:
        return DashboardRange(
          preset: preset,
          range: customRange ?? DateTimeRange(start: today, end: today),
          mirrorRange: null,
        );
    }
  }
}

// ─── Category Scorecard ─────────────────────────────────────────────────────

class CategoryScorecard {
  final int? categoryId;
  final String categoryName;
  final String emoji;
  final double revenue;
  final int pieces;
  final int shopCount;
  final List<int> sparklineData; // 7 daily piece totals
  final String? starProductName;
  final double starProductSharePercent;

  const CategoryScorecard({
    required this.categoryId,
    required this.categoryName,
    required this.emoji,
    required this.revenue,
    required this.pieces,
    required this.shopCount,
    required this.sparklineData,
    this.starProductName,
    this.starProductSharePercent = 0,
  });
}

// ─── Revenue Anatomy ────────────────────────────────────────────────────────

class CategoryMixRow {
  final int? categoryId;
  final String categoryName;
  final String emoji;
  final double revenue;
  final double sharePercent;
  final double? trendPercent; // vs mirror period

  const CategoryMixRow({
    required this.categoryId,
    required this.categoryName,
    required this.emoji,
    required this.revenue,
    required this.sharePercent,
    this.trendPercent,
  });
}

class ShopConcentrationRow {
  final int shopId;
  final String shopName;
  final String? area;
  final double revenue;
  final double sharePercent;
  final int categoryBreadth;
  final List<String> categoryEmojis;

  const ShopConcentrationRow({
    required this.shopId,
    required this.shopName,
    this.area,
    required this.revenue,
    required this.sharePercent,
    required this.categoryBreadth,
    required this.categoryEmojis,
  });
}

class ProductLeaderRow {
  final int productId;
  final String productName;
  final int? categoryId;
  final String categoryEmoji;
  final double revenue;
  final int qty;
  final int shopCount;

  const ProductLeaderRow({
    required this.productId,
    required this.productName,
    this.categoryId,
    required this.categoryEmoji,
    required this.revenue,
    required this.qty,
    required this.shopCount,
  });
}

// ─── Attention Flags ────────────────────────────────────────────────────────

enum AttentionFlagType {
  decliningCategory,
  inactiveShop,
  newHigh,
  concentrationRisk,
  zeroDay,
}

class AttentionFlag {
  final AttentionFlagType type;
  final String icon;
  final String message;
  final String? detail;

  const AttentionFlag({
    required this.type,
    required this.icon,
    required this.message,
    this.detail,
  });
}

// ─── Dashboard Settings ─────────────────────────────────────────────────────

class DashboardSettings {
  final bool showPulse;
  final bool showCategoryCards;
  final bool showRevenueAnatomy;
  final bool showOperationalPatterns;
  final bool showAttentionFlags;
  final bool showCategoryMix;
  final bool showShopConcentration;
  final bool showProductLeaderboard;
  final bool showHeatmap;
  final bool showRevenueTrend;

  const DashboardSettings({
    this.showPulse = true,
    this.showCategoryCards = true,
    this.showRevenueAnatomy = true,
    this.showOperationalPatterns = true,
    this.showAttentionFlags = true,
    this.showCategoryMix = true,
    this.showShopConcentration = true,
    this.showProductLeaderboard = true,
    this.showHeatmap = true,
    this.showRevenueTrend = true,
  });

  DashboardSettings copyWith({
    bool? showPulse,
    bool? showCategoryCards,
    bool? showRevenueAnatomy,
    bool? showOperationalPatterns,
    bool? showAttentionFlags,
    bool? showCategoryMix,
    bool? showShopConcentration,
    bool? showProductLeaderboard,
    bool? showHeatmap,
    bool? showRevenueTrend,
  }) {
    return DashboardSettings(
      showPulse: showPulse ?? this.showPulse,
      showCategoryCards: showCategoryCards ?? this.showCategoryCards,
      showRevenueAnatomy: showRevenueAnatomy ?? this.showRevenueAnatomy,
      showOperationalPatterns: showOperationalPatterns ?? this.showOperationalPatterns,
      showAttentionFlags: showAttentionFlags ?? this.showAttentionFlags,
      showCategoryMix: showCategoryMix ?? this.showCategoryMix,
      showShopConcentration: showShopConcentration ?? this.showShopConcentration,
      showProductLeaderboard: showProductLeaderboard ?? this.showProductLeaderboard,
      showHeatmap: showHeatmap ?? this.showHeatmap,
      showRevenueTrend: showRevenueTrend ?? this.showRevenueTrend,
    );
  }

  /// Number of enabled sections (main only).
  int get enabledSectionCount =>
      [showPulse, showCategoryCards, showRevenueAnatomy, showOperationalPatterns, showAttentionFlags]
          .where((v) => v)
          .length;
}
