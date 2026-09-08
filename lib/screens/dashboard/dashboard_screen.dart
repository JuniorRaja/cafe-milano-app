import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/dashboard_models.dart';
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
import '../../widgets/dashboard/ledger_kpi_card.dart';
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
    DashboardPreset.custom: 'Custom…',
  };

  static const _tabs = [Tab(text: 'Sales'), Tab(text: 'Products'), Tab(text: 'Shops'), Tab(text: 'Alerts')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(dashboardSettingsProvider);
    final range = ref.watch(dashboardRangeProvider);

    final trimmedName = ref
        .watch(businessInfoProvider)
        .valueOrNull
        ?.name
        .trim();
    final businessName = (trimmedName == null || trimmedName.isEmpty)
        ? null
        : trimmedName;

    return DefaultTabController(
      length: _tabs.length,
      child: AppScaffold(
        caption: greetingFor(),
        title: businessName ?? 'Business Overview',
        leading: const ShellDrawerButton(),
        actions: [
          IconButton(
            onPressed: () => refreshDashboard(ref),
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.textPrimary,
            tooltip: 'Refresh',
          ),
        ],
        bottom: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                0,
                AppSpace.s2,
                AppSpace.s1,
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
            TabBar(
              tabs: _tabs,
              labelColor: AppColors.brandDeep,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: AppType.label.copyWith(fontWeight: FontWeight.w700),
              unselectedLabelStyle: AppType.label,
              indicatorColor: AppColors.brandPrimary,
              indicatorWeight: 2.5,
              dividerColor: AppColors.border,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _SalesTab(settings: settings, range: range),
            _ProductsTab(settings: settings),
            _ShopsTab(settings: settings),
            _AlertsTab(settings: settings),
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

  String _formatDateIndicator(DashboardRange range) {
    final fmt = DateFormat('d MMM');
    final fmtYear = DateFormat('d MMM yyyy');
    final start = range.range.start;
    final end = range.range.end;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (start == end) {
      if (start == today) {
        return 'Today, ${DateFormat('d MMMM yyyy').format(start)}';
      }
      return fmtYear.format(start);
    }

    if (start.year == end.year && start.year == now.year) {
      return '${fmt.format(start)} – ${fmt.format(end)}';
    }
    return '${fmtYear.format(start)} – ${fmtYear.format(end)}';
  }
}

// ─── Tab bodies ─────────────────────────────────────────────────────────────

Widget _tabBody(BuildContext ctx, List<Widget> children) => SingleChildScrollView(
  padding: EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s4, AppSpace.s4, AppShell.bottomInset(ctx)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
);

class _SalesTab extends StatelessWidget {
  const _SalesTab({required this.settings, required this.range});
  final DashboardSettings settings;
  final DashboardRange range;

  @override
  Widget build(BuildContext context) {
    final showPulse = settings.showPulse && range.preset == DashboardPreset.today;
    final showLedger = settings.showLedgerKpis;
    final showOutstanding = settings.showOutstanding;
    final showMix = settings.showRevenueAnatomy && settings.showCategoryMix;
    final showHeatmap = settings.showOperationalPatterns && settings.showHeatmap;

    if (!showPulse && !showLedger && !showOutstanding && !showMix && !showHeatmap) {
      return _empty();
    }

    return _tabBody(context, [
      if (showPulse) ...[const PulseCard(), const SizedBox(height: AppSpace.s4)],
      if (showLedger) ...[const LedgerKpiCard(), const SizedBox(height: AppSpace.s4)],
      if (showOutstanding) ...[const OutstandingCard(), const SizedBox(height: AppSpace.s4)],
      if (showMix) ...[const RevenueMixCard(), const SizedBox(height: AppSpace.s4)],
      if (showHeatmap) ...[const WeekdayHeatmapWidget(), const SizedBox(height: AppSpace.s4)],
    ]);
  }
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab({required this.settings});
  final DashboardSettings settings;

  @override
  Widget build(BuildContext context) {
    final showScores = settings.showCategoryCards;
    final showLeader = settings.showRevenueAnatomy && settings.showProductLeaderboard;

    if (!showScores && !showLeader) return _empty();

    return _tabBody(context, [
      if (showScores) ...[const CategoryScorecardsWidget(), const SizedBox(height: AppSpace.s4)],
      if (showLeader) ...[const ProductLeaderboardCard(), const SizedBox(height: AppSpace.s4)],
    ]);
  }
}

class _ShopsTab extends StatelessWidget {
  const _ShopsTab({required this.settings});
  final DashboardSettings settings;

  @override
  Widget build(BuildContext context) {
    final showConc = settings.showRevenueAnatomy && settings.showShopConcentration;

    if (!showConc) return _empty();

    return _tabBody(context, [
      const ShopConcentrationCard(),
      const SizedBox(height: AppSpace.s4),
    ]);
  }
}

class _AlertsTab extends StatelessWidget {
  const _AlertsTab({required this.settings});
  final DashboardSettings settings;

  @override
  Widget build(BuildContext context) {
    if (!settings.showAttentionFlags) return _empty();

    return _tabBody(context, [
      const AttentionFlagsWidget(),
      const SizedBox(height: AppSpace.s4),
    ]);
  }
}

Widget _empty() {
  return Center(
    child: Text(
      'All cards in this tab are hidden.\nCheck Dashboard settings to show them.',
      textAlign: TextAlign.center,
      style: AppType.bodyS.copyWith(color: AppColors.textTertiary),
    ),
  );
}
