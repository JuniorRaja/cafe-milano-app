import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../providers/dashboard_settings_provider.dart';

class DashboardSettingsScreen extends ConsumerWidget {
  const DashboardSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(dashboardSettingsProvider);
    final notifier = ref.read(dashboardSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sections header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'SECTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _ToggleTile(
                  title: 'The Pulse',
                  subtitle: "Today's snapshot",
                  value: settings.showPulse,
                  onChanged: (v) => notifier.toggle(kDashPulse, v),
                  onInfo: () => context.push('/profile/dashboard-settings/help',
                      extra: 'today_revenue'),
                ),
                const Divider(height: 1, indent: 16),
                _ToggleTile(
                  title: 'Category Scorecards',
                  subtitle: 'Per-category health cards',
                  value: settings.showCategoryCards,
                  onChanged: (v) => notifier.toggle(kDashCategoryCards, v),
                  onInfo: () => context.push('/profile/dashboard-settings/help',
                      extra: 'category_revenue'),
                ),
                const Divider(height: 1, indent: 16),
                _ToggleTile(
                  title: 'Revenue Anatomy',
                  subtitle: 'Mix, concentration & leaderboard',
                  value: settings.showRevenueAnatomy,
                  onChanged: (v) => notifier.toggle(kDashRevenueAnatomy, v),
                  onInfo: () => context.push('/profile/dashboard-settings/help',
                      extra: 'category_mix'),
                ),
                const Divider(height: 1, indent: 16),
                _ToggleTile(
                  title: 'Operational Patterns',
                  subtitle: 'Day-of-week heatmap',
                  value: settings.showOperationalPatterns,
                  onChanged: (v) =>
                      notifier.toggle(kDashOperationalPatterns, v),
                  onInfo: () => context.push('/profile/dashboard-settings/help',
                      extra: 'heatmap'),
                ),
                const Divider(height: 1, indent: 16),
                _ToggleTile(
                  title: 'Attention Flags',
                  subtitle: 'Smart alerts & anomalies',
                  value: settings.showAttentionFlags,
                  onChanged: (v) => notifier.toggle(kDashAttentionFlags, v),
                  onInfo: () => context.push('/profile/dashboard-settings/help',
                      extra: 'declining_flag'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sub-sections header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'SUB-SECTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _ToggleTile(
                  title: 'Category Revenue Mix',
                  subtitle: 'Donut chart',
                  value: settings.showCategoryMix,
                  onChanged: (v) => notifier.toggle(kDashCategoryMix, v),
                  onInfo: () => context.push('/profile/dashboard-settings/help',
                      extra: 'category_mix'),
                ),
                const Divider(height: 1, indent: 16),
                _ToggleTile(
                  title: 'Shop Concentration',
                  subtitle: 'Top shops by revenue',
                  value: settings.showShopConcentration,
                  onChanged: (v) =>
                      notifier.toggle(kDashShopConcentration, v),
                  onInfo: () => context.push('/profile/dashboard-settings/help',
                      extra: 'shop_concentration'),
                ),
                const Divider(height: 1, indent: 16),
                _ToggleTile(
                  title: 'Product Leaderboard',
                  subtitle: 'Top 10 products',
                  value: settings.showProductLeaderboard,
                  onChanged: (v) =>
                      notifier.toggle(kDashProductLeaderboard, v),
                  onInfo: () => context.push('/profile/dashboard-settings/help',
                      extra: 'product_leaderboard'),
                ),
                const Divider(height: 1, indent: 16),
                _ToggleTile(
                  title: 'Day-of-Week Heatmap',
                  subtitle: 'Demand by weekday',
                  value: settings.showHeatmap,
                  onChanged: (v) => notifier.toggle(kDashHeatmap, v),
                  onInfo: () => context.push('/profile/dashboard-settings/help',
                      extra: 'heatmap'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // KPI Help Guide link
          Card(
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Text('📖', style: TextStyle(fontSize: 22)),
              title: const Text(
                'KPI Help Guide',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Learn what each metric means',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile/dashboard-settings/help'),
            ),
          ),
        ],
      ),
    );
  }
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
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.info_outline, size: 20, color: Colors.grey.shade400),
            onPressed: onInfo,
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: kBrandBrown,
          ),
        ],
      ),
    );
  }
}
