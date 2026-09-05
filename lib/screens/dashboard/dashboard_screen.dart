import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/dashboard_models.dart';
import '../../providers/category_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/dashboard_settings_provider.dart';
import '../../providers/date_provider.dart';
import '../../widgets/dashboard/date_range_pill.dart';
import '../../widgets/dashboard/pulse_card.dart';
import '../../widgets/dashboard/category_scorecards.dart';
import '../../widgets/dashboard/revenue_mix_card.dart';
import '../../widgets/dashboard/shop_concentration_card.dart';
import '../../widgets/dashboard/product_leaderboard_card.dart';
import '../../widgets/dashboard/weekday_heatmap.dart';
import '../../widgets/dashboard/attention_flags.dart';
import '../../widgets/dashboard/outstanding_card.dart';
import '../../widgets/shell/app_shell.dart';
import '../../utils/greeting.dart';
import '../../widgets/ui/ui.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(dashboardSettingsProvider);
    final range = ref.watch(dashboardRangeProvider);

    return AppScaffold(
      // The greeting the owner asked to have back, and no name with it — see
      // `greetingFor`. It is the caption rather than the title because the
      // title answers what the screen *is*, and "Good morning" does not.
      //
      // The hour is read when this builds, so a phone left open across noon
      // keeps the old greeting until something else rebuilds the screen. The
      // deleted version did the same, and an hourly ticker for a caption is
      // not worth a timer.
      caption: greetingFor(),
      title: 'Business Overview',
      leading: const ShellDrawerButton(),
      actions: [
        IconButton(
          onPressed: () => _refreshDashboard(ref),
          icon: const Icon(Icons.refresh_rounded),
          color: AppColors.textPrimary,
          tooltip: 'Refresh',
        ),
      ],
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DateRangePill(),
          const SizedBox(height: AppSpace.s1),
          Padding(
            padding: AppSpace.page,
            child: Text(
              _formatDateIndicator(range),
              style: AppType.bodyS.copyWith(color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: AppSpace.s3),
        ],
      ),
      body: SingleChildScrollView(
        // The nav bar floats over the body now, so the room for it is this
        // screen's to leave. See `AppShell.bottomInset`.
        padding: EdgeInsets.fromLTRB(
          AppSpace.s4,
          0,
          AppSpace.s4,
          AppShell.bottomInset(context),
        ),
        child: Column(
          children: [
            // Section 1 — The Pulse
            if (settings.showPulse) ...[
              const PulseCard(),
              const SizedBox(height: AppSpace.s4),
            ],

            // Section 2 — Outstanding Receivables
            if (settings.showOutstanding) ...[
              const OutstandingCard(),
              const SizedBox(height: AppSpace.s4),
            ],

            // Section 3 — Category Scorecards
            if (settings.showCategoryCards) ...[
              const CategoryScorecardsWidget(),
              const SizedBox(height: AppSpace.s4),
            ],

            // Section 3 — Revenue Anatomy
            if (settings.showRevenueAnatomy) ...[
              if (settings.showCategoryMix) ...[
                const RevenueMixCard(),
                const SizedBox(height: AppSpace.s3),
              ],
              if (settings.showShopConcentration) ...[
                const ShopConcentrationCard(),
                const SizedBox(height: AppSpace.s3),
              ],
              if (settings.showProductLeaderboard) ...[
                const ProductLeaderboardCard(),
                const SizedBox(height: AppSpace.s4),
              ],
            ],

            // Section 4 — Operational Patterns
            if (settings.showOperationalPatterns) ...[
              if (settings.showHeatmap) ...[
                const WeekdayHeatmapWidget(),
                const SizedBox(height: AppSpace.s4),
              ],
            ],

            // Section 5 — Attention Flags (at the bottom)
            if (settings.showAttentionFlags) ...[
              const AttentionFlagsWidget(),
              const SizedBox(height: AppSpace.s4),
            ],
          ],
        ),
      ),
    );
  }

  void _refreshDashboard(WidgetRef ref) {
    ref.invalidate(todayProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(shopConcentrationDataProvider);
    ref.invalidate(categoryScoresDataProvider);
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
