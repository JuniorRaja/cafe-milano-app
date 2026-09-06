import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart' show AppRoutes;
import '../../providers/dashboard_settings_provider.dart';
import '../../widgets/ui/ui.dart';

class DashboardSettingsScreen extends ConsumerWidget {
  const DashboardSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(dashboardSettingsProvider);
    final notifier = ref.read(dashboardSettingsProvider.notifier);

    return AppScaffold(
      title: 'Dashboard Settings',
      background: AppColors.bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          0,
          AppSpace.s4,
          AppSpace.s6,
        ),
        children: [
          const SectionHeader(
            title: 'Sections',
            padding: EdgeInsets.only(bottom: AppSpace.s2),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ToggleTile(
                  title: 'The Pulse',
                  subtitle: "Today's snapshot",
                  value: settings.showPulse,
                  onChanged: (v) => notifier.toggle(kDashPulse, v),
                  onInfo: () =>
                      context.push(AppRoutes.kpiHelp, extra: 'today_revenue'),
                ),
                const _TileDivider(),
                _ToggleTile(
                  title: 'Outstanding Receivables',
                  subtitle: 'Total owed across all shops',
                  value: settings.showOutstanding,
                  onChanged: (v) => notifier.toggle(kDashOutstanding, v),
                  onInfo: () =>
                      context.push(AppRoutes.kpiHelp, extra: 'today_revenue'),
                ),
                const _TileDivider(),
                _ToggleTile(
                  title: 'Category Scorecards',
                  subtitle: 'Per-category health cards',
                  value: settings.showCategoryCards,
                  onChanged: (v) => notifier.toggle(kDashCategoryCards, v),
                  onInfo: () => context.push(
                    AppRoutes.kpiHelp,
                    extra: 'category_revenue',
                  ),
                ),
                const _TileDivider(),
                _ToggleTile(
                  title: 'Revenue Anatomy',
                  subtitle: 'Mix, concentration & leaderboard',
                  value: settings.showRevenueAnatomy,
                  onChanged: (v) => notifier.toggle(kDashRevenueAnatomy, v),
                  onInfo: () =>
                      context.push(AppRoutes.kpiHelp, extra: 'category_mix'),
                ),
                const _TileDivider(),
                _ToggleTile(
                  title: 'Operational Patterns',
                  subtitle: 'Day-of-week heatmap',
                  value: settings.showOperationalPatterns,
                  onChanged: (v) => notifier.toggle(kDashOperationalPatterns, v),
                  onInfo: () =>
                      context.push(AppRoutes.kpiHelp, extra: 'heatmap'),
                ),
                const _TileDivider(),
                _ToggleTile(
                  title: 'Attention Flags',
                  subtitle: 'Smart alerts & anomalies',
                  value: settings.showAttentionFlags,
                  onChanged: (v) => notifier.toggle(kDashAttentionFlags, v),
                  onInfo: () =>
                      context.push(AppRoutes.kpiHelp, extra: 'declining_flag'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s5),

          const SectionHeader(
            title: 'Sub-sections',
            padding: EdgeInsets.only(bottom: AppSpace.s2),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ToggleTile(
                  title: 'Category Revenue Mix',
                  subtitle: 'Donut chart',
                  value: settings.showCategoryMix,
                  onChanged: (v) => notifier.toggle(kDashCategoryMix, v),
                  onInfo: () =>
                      context.push(AppRoutes.kpiHelp, extra: 'category_mix'),
                ),
                const _TileDivider(),
                _ToggleTile(
                  title: 'Shop Concentration',
                  subtitle: 'Top shops by revenue',
                  value: settings.showShopConcentration,
                  onChanged: (v) => notifier.toggle(kDashShopConcentration, v),
                  onInfo: () => context.push(
                    AppRoutes.kpiHelp,
                    extra: 'shop_concentration',
                  ),
                ),
                const _TileDivider(),
                _ToggleTile(
                  title: 'Product Leaderboard',
                  subtitle: 'Top 10 products',
                  value: settings.showProductLeaderboard,
                  onChanged: (v) => notifier.toggle(kDashProductLeaderboard, v),
                  onInfo: () => context.push(
                    AppRoutes.kpiHelp,
                    extra: 'product_leaderboard',
                  ),
                ),
                const _TileDivider(),
                _ToggleTile(
                  title: 'Day-of-Week Heatmap',
                  subtitle: 'Demand by weekday',
                  value: settings.showHeatmap,
                  onChanged: (v) => notifier.toggle(kDashHeatmap, v),
                  onInfo: () =>
                      context.push(AppRoutes.kpiHelp, extra: 'heatmap'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s5),

          AppCard(
            padding: EdgeInsets.zero,
            onTap: () => context.push(AppRoutes.kpiHelp),
            child: ListTile(
              leading: const Text('📖', style: AppType.titleL),
              title: Text('KPI Help Guide', style: AppType.titleS),
              subtitle: Text(
                'Learn what each metric means',
                style: AppType.bodyS.copyWith(color: AppColors.textSecondary),
              ),
              // No onTap here: the tap lives on the AppCard above so the ripple
              // clips to rM. A ListTile with its own onTap would swallow it.
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: AppSpace.s4, color: AppColors.border);
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.onInfo,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: AppType.bodyS.copyWith(color: AppColors.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(
              Icons.info_outline,
              size: 20,
              color: AppColors.textTertiary,
            ),
            onPressed: onInfo,
          ),
          // No colour override. switchTheme in app_theme.dart already gives
          // this a brown thumb on a gold track; the override painted the track
          // brown too, so "on" was a brown blob on brown.
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
