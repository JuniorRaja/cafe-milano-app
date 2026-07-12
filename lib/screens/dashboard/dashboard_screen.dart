import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../models/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/dashboard_settings_provider.dart';
import '../../widgets/dashboard/date_range_pill.dart';
import '../../widgets/dashboard/pulse_card.dart';
import '../../widgets/dashboard/category_scorecards.dart';
import '../../widgets/dashboard/revenue_mix_card.dart';
import '../../widgets/dashboard/shop_concentration_card.dart';
import '../../widgets/dashboard/product_leaderboard_card.dart';
import '../../widgets/dashboard/weekday_heatmap.dart';
import '../../widgets/dashboard/attention_flags.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(dashboardSettingsProvider);
    final range = ref.watch(dashboardRangeProvider);

    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App bar area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.dashboard_rounded,
                      color: kBrandGold, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'DASHBOARD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const Text(
                          'Business Overview',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: kBrandBrown,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Refresh button
                  IconButton(
                    onPressed: () => _refreshDashboard(ref),
                    icon: const Icon(Icons.refresh_rounded),
                    color: kBrandBrown,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),

            // Date range selector
            const DateRangePill(),
            const SizedBox(height: 6),

            // Date indicator — shows resolved range
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _formatDateIndicator(range),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Scrollable sections
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                child: Column(
                  children: [
                    // Section 1 — The Pulse
                    if (settings.showPulse) ...[
                      const PulseCard(),
                      const SizedBox(height: 16),
                    ],

                    // Section 2 — Category Scorecards
                    if (settings.showCategoryCards) ...[
                      const CategoryScorecardsWidget(),
                      const SizedBox(height: 16),
                    ],

                    // Section 3 — Revenue Anatomy
                    if (settings.showRevenueAnatomy) ...[
                      if (settings.showCategoryMix) ...[
                        const RevenueMixCard(),
                        const SizedBox(height: 12),
                      ],
                      if (settings.showShopConcentration) ...[
                        const ShopConcentrationCard(),
                        const SizedBox(height: 12),
                      ],
                      if (settings.showProductLeaderboard) ...[
                        const ProductLeaderboardCard(),
                        const SizedBox(height: 16),
                      ],
                    ],

                    // Section 4 — Operational Patterns
                    if (settings.showOperationalPatterns) ...[
                      if (settings.showHeatmap) ...[
                        const WeekdayHeatmapWidget(),
                        const SizedBox(height: 16),
                      ],
                    ],

                    // Section 5 — Attention Flags (at the bottom)
                    if (settings.showAttentionFlags) ...[
                      const AttentionFlagsWidget(),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _refreshDashboard(WidgetRef ref) {
    ref.invalidate(todayRevenueProvider);
    ref.invalidate(revenueDeltaProvider);
    ref.invalidate(shopsServedTodayProvider);
    ref.invalidate(pendingConfirmationsProvider);
    ref.invalidate(categoryScorecardsProvider);
    ref.invalidate(categoryMixProvider);
    ref.invalidate(shopConcentrationProvider);
    ref.invalidate(productLeaderboardProvider);
    ref.invalidate(weekdayHeatmapProvider);
    ref.invalidate(attentionFlagsProvider);
  }

  String _formatDateIndicator(DashboardRange range) {
    final fmt = DateFormat('d MMM');
    final fmtYear = DateFormat('d MMM yyyy');
    final start = range.range.start;
    final end = range.range.end;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (start == end) {
      if (start == today) return 'Today, ${DateFormat('d MMMM yyyy').format(start)}';
      return fmtYear.format(start);
    }

    // Same year as now — omit year from start
    if (start.year == end.year && start.year == now.year) {
      return '${fmt.format(start)} – ${fmt.format(end)}';
    }
    return '${fmtYear.format(start)} – ${fmtYear.format(end)}';
  }
}
