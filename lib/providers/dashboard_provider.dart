import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_models.dart';

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

// ─── Pulse Providers (stubs — wired in Phase B) ─────────────────────────────

final todayRevenueProvider = FutureProvider<double>((ref) async {
  return 0.0;
});

final revenueDeltaProvider = FutureProvider<double?>((ref) async {
  return null; // percentage change
});

final shopsServedTodayProvider = FutureProvider<(int served, int total)>((ref) async {
  return (0, 0);
});

final pendingConfirmationsProvider = FutureProvider<int>((ref) async {
  return 0;
});

// ─── Category Scorecards (stub) ─────────────────────────────────────────────

final categoryScorecardsProvider = FutureProvider<List<CategoryScorecard>>((ref) async {
  return [];
});

// ─── Revenue Anatomy (stubs) ────────────────────────────────────────────────

final categoryMixProvider = FutureProvider<List<CategoryMixRow>>((ref) async {
  return [];
});

final shopConcentrationProvider = FutureProvider<List<ShopConcentrationRow>>((ref) async {
  return [];
});

final productLeaderboardProvider = FutureProvider<List<ProductLeaderRow>>((ref) async {
  return [];
});

// ─── Operational Patterns (stubs) ───────────────────────────────────────────

/// `Map<categoryId, Map<weekday (0=Mon..6=Sun), avgPieces>>`
final weekdayHeatmapProvider = FutureProvider<Map<int?, Map<int, double>>>((ref) async {
  return {};
});

/// `Map<date, Map<categoryId, revenue>>`
final stackedRevenueTrendProvider = FutureProvider<Map<DateTime, Map<int?, double>>>((ref) async {
  return {};
});

// ─── Attention Flags (stub) ─────────────────────────────────────────────────

final attentionFlagsProvider = FutureProvider<List<AttentionFlag>>((ref) async {
  return [];
});
