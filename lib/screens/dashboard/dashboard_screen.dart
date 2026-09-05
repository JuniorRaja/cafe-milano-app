import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/dashboard_models.dart';
import '../../providers/category_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/business_info_provider.dart';
import '../../providers/dashboard_settings_provider.dart';
import '../../providers/date_provider.dart';
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

  static const _presetLabels = {
    DashboardPreset.today: 'Today',
    DashboardPreset.thisWeek: 'This week',
    DashboardPreset.lastWeek: 'Last week',
    DashboardPreset.thisMonth: 'This month',
    DashboardPreset.lastMonth: 'Last month',
    DashboardPreset.last90: 'Last 90 days',
    DashboardPreset.custom: 'Custom\u2026',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(dashboardSettingsProvider);
    final range = ref.watch(dashboardRangeProvider);

    // The owner's own business, not one of the shops they supply. Falls back
    // to the generic title when Business Info has not been filled in, so the
    // header is never blank and no name is ever hardcoded.
    final businessName = ref.watch(businessInfoProvider).maybeWhen(
          data: (info) {
            final name = info?.name.trim() ?? '';
            return name.isEmpty ? null : name;
          },
          orElse: () => null,
        );

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
      title: businessName ?? 'Business Overview',
      leading: const ShellDrawerButton(),
      actions: [
        IconButton(
          onPressed: () => _refreshDashboard(ref),
          icon: const Icon(Icons.refresh_rounded),
          color: AppColors.textPrimary,
          tooltip: 'Refresh',
        ),
      ],
      // The date on the left, the period control on the right. It was a
      // scrolling row of seven pills above the date, which spent a whole band
      // of the screen on a control that is touched once a week — and could not
      // be shared with the Ledger, because it was wired into this screen's own
      // range. Both screens use `HeaderMenu` now, each on its own state.
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          0,
          AppSpace.s2,
          AppSpace.s3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _formatDateIndicator(range),
                style: AppType.bodyS.copyWith(color: AppColors.textSecondary),
              ),
            ),
            HeaderMenu<DashboardPreset>(
              label: _presetLabels[range.preset] ?? 'Period',
              tooltip: 'Change the period',
              values: DashboardPreset.values,
              labelOf: (preset) => _presetLabels[preset]!,
              selected: range.preset,
              onSelected: (preset) => _pickPeriod(context, ref, preset),
            ),
          ],
        ),
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
            // Section 1 — The Pulse, on the daily view only. It answers
            // "how is today going" — against a quarter it is not a pulse, it
            // is a different question the cards below already answer.
            if (settings.showPulse &&
                range.preset == DashboardPreset.today) ...[
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

  Future<void> _pickPeriod(
    BuildContext context,
    WidgetRef ref,
    DashboardPreset preset,
  ) async {
    if (preset != DashboardPreset.custom) {
      ref.read(dashboardRangeProvider.notifier).selectPreset(preset);
      return;
    }

    final today = ref.read(todayProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: today.subtract(const Duration(days: 7)),
        end: today,
      ),
    );
    if (picked == null) return;
    ref
        .read(dashboardRangeProvider.notifier)
        .selectCustomRange(picked.start, picked.end);
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
