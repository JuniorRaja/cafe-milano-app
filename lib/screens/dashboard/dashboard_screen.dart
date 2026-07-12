import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../../providers/dashboard_settings_provider.dart';
import '../../widgets/dashboard/date_range_pill.dart';
import '../../widgets/dashboard/pulse_card.dart';
import '../../widgets/dashboard/category_scorecards.dart';
import '../../widgets/dashboard/revenue_mix_card.dart';
import '../../widgets/dashboard/shop_concentration_card.dart';
import '../../widgets/dashboard/product_leaderboard_card.dart';
import '../../widgets/dashboard/weekday_heatmap.dart';
import '../../widgets/dashboard/stacked_revenue_chart.dart';
import '../../widgets/dashboard/attention_flags.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(dashboardSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                  Column(
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
                ],
              ),
            ),

            // Date range selector
            const DateRangePill(),
            const SizedBox(height: 12),

            // Scrollable sections
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                child: Column(
                  children: [
                    // Section 5 — Attention Flags (between Pulse and Scorecards)
                    if (settings.showAttentionFlags) ...[
                      const AttentionFlagsWidget(),
                      const SizedBox(height: 12),
                    ],

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
                        const SizedBox(height: 12),
                      ],
                      if (settings.showRevenueTrend) ...[
                        const StackedRevenueChart(),
                        const SizedBox(height: 16),
                      ],
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
}
