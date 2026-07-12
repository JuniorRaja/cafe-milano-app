import 'package:flutter/material.dart';
import '../../app.dart';

class KpiHelpScreen extends StatefulWidget {
  const KpiHelpScreen({super.key, this.scrollToSection});

  /// Optional section key to auto-scroll to on open.
  final String? scrollToSection;

  @override
  State<KpiHelpScreen> createState() => _KpiHelpScreenState();
}

class _KpiHelpScreenState extends State<KpiHelpScreen> {
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  String? _expandedKey;

  static const _entries = <_KpiEntry>[
    _KpiEntry(
      key: 'today_revenue',
      title: "Today's Revenue",
      icon: '💰',
      text:
          "Total sales value from all orders placed today. Calculated as quantity × price for every item across all shops.",
    ),
    _KpiEntry(
      key: 'vs_last_week',
      title: 'vs Same Day Last Week',
      icon: '📊',
      text:
          "Compares today's revenue to the same weekday last week. Green arrow = doing better; red = lower. Helps spot if today is unusually slow or strong.",
    ),
    _KpiEntry(
      key: 'shops_served',
      title: 'Shops Served',
      icon: '🏪',
      text:
          'How many of your active shops placed at least one order today, out of the total. Low number early in the day is normal — check again by afternoon.',
    ),
    _KpiEntry(
      key: 'pending',
      title: 'Pending Confirmations',
      icon: '⏳',
      text:
          "Orders entered today that haven't been confirmed yet. Zero means all orders are locked in for production.",
    ),
    _KpiEntry(
      key: 'category_revenue',
      title: 'Category Revenue',
      icon: '📂',
      text:
          'Total sales for one product category in the selected time period. Shows which product lines bring in the most money.',
    ),
    _KpiEntry(
      key: 'volume_reach',
      title: 'Volume & Reach',
      icon: '📦',
      text:
          'Pieces produced and number of shops ordering from this category. High reach = universal staple; low reach = niche.',
    ),
    _KpiEntry(
      key: 'sparkline',
      title: '7-Day Sparkline',
      icon: '📈',
      text:
          'Tiny chart showing daily production for the last 7 days. Flat = steady demand. Spikes = weekend surge or event orders.',
    ),
    _KpiEntry(
      key: 'star_product',
      title: 'Star Product',
      icon: '⭐',
      text:
          "Highest-earning product within a category. The % shows how much the category depends on one item. High % = risk if that product dips.",
    ),
    _KpiEntry(
      key: 'category_mix',
      title: 'Category Revenue Mix',
      icon: '🍩',
      text:
          'Pie chart showing what fraction of total revenue comes from each category. Spot over-dependence on one product line.',
    ),
    _KpiEntry(
      key: 'vs_previous',
      title: 'vs Previous Period',
      icon: '🔄',
      text:
          'Compares current period revenue to equivalent previous period. Shows which categories are growing or shrinking.',
    ),
    _KpiEntry(
      key: 'shop_concentration',
      title: 'Shop Concentration',
      icon: '🎯',
      text:
          "Ranks top shops by spend. If one shop is > 25% of revenue, that's a risk — losing them would hurt significantly.",
    ),
    _KpiEntry(
      key: 'category_breadth',
      title: 'Category Breadth',
      icon: '🌐',
      text:
          'How many categories a shop orders from. Few categories = upsell opportunity.',
    ),
    _KpiEntry(
      key: 'product_leaderboard',
      title: 'Product Leaderboard',
      icon: '🏆',
      text:
          'Top 10 products by revenue. A top product ordered by only 1–2 shops = dependency risk.',
    ),
    _KpiEntry(
      key: 'heatmap',
      title: 'Day-of-Week Heatmap',
      icon: '📅',
      text:
          'Average demand per category per weekday (last 4 weeks). Plan production — more cakes on Fridays, steady buns daily.',
    ),
    _KpiEntry(
      key: 'revenue_trend',
      title: 'Revenue Trend (Stacked)',
      icon: '📈',
      text:
          '30-day chart with coloured layers per category. If a layer thins, that category is declining even if total looks fine.',
    ),
    _KpiEntry(
      key: 'declining_flag',
      title: 'Declining Category Flag',
      icon: '📉',
      text:
          'Appears when a category drops > 15% vs previous cycle. Could mean supply issues, seasonal drop, or lost customer.',
    ),
    _KpiEntry(
      key: 'inactive_flag',
      title: 'Inactive Shop Flag',
      icon: '🏚️',
      text:
          "A regularly-ordering shop hasn't ordered in 7+ days. Worth a phone call.",
    ),
    _KpiEntry(
      key: 'concentration_flag',
      title: 'Concentration Risk Flag',
      icon: '⚖️',
      text:
          'One shop > 25% of total revenue. Not necessarily bad, but diversification protects you.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    for (final entry in _entries) {
      _sectionKeys[entry.key] = GlobalKey();
    }
    if (widget.scrollToSection != null) {
      _expandedKey = widget.scrollToSection;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToKey());
    }
  }

  void _scrollToKey() {
    final key = _sectionKeys[widget.scrollToSection];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KPI Help Guide',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: _entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          final isExpanded = _expandedKey == entry.key;

          return Card(
            key: _sectionKeys[entry.key],
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ExpansionTile(
              initiallyExpanded: isExpanded,
              leading: Text(entry.icon, style: const TextStyle(fontSize: 22)),
              title: Text(
                entry.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: kBrandBrown,
                ),
              ),
              onExpansionChanged: (expanded) {
                setState(() => _expandedKey = expanded ? entry.key : null);
              },
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    entry.text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KpiEntry {
  const _KpiEntry({
    required this.key,
    required this.title,
    required this.icon,
    required this.text,
  });
  final String key;
  final String title;
  final String icon;
  final String text;
}
