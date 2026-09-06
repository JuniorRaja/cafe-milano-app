import 'package:flutter/material.dart';
import '../ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../utils/money.dart';
import '../../theme/brand_config.dart';

// Consistent colour palette for category slices
const _kSliceColors = [
  Color(0xFF4A2C2A), // brand brown
  Color(0xFFFFC000), // brand gold
  Color(0xFF2E7D32), // green
  Color(0xFF1565C0), // blue
  Color(0xFFE65100), // orange
  Color(0xFF6A1B9A), // purple
  Color(0xFF00838F), // teal
  Color(0xFFC62828), // red
  Color(0xFF4E342E), // brown
  Color(0xFF37474F), // blue-grey
];

class RevenueMixCard extends ConsumerWidget {
  const RevenueMixCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    final mixAsync = ref.watch(categoryMixProvider);

    return RepaintBoundary(
      child: AppCard(padding: const EdgeInsets.all(20), border: Border.all(color: AppColors.border), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🍩', style: AppType.titleM),
                SizedBox(width: 6),
                Text(
                  'Category Revenue Mix',
                  style: AppType.titleS.copyWith(fontWeight: FontWeight.w700, color: AppColors.brandDeep),
                ),
              ],
            ),
            const SizedBox(height: 16),
            mixAsync.when(
              data: (rows) {
                if (rows.isEmpty) return _emptyState();
                return _buildContent(brand, rows);
              },
              loading: () => const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandDeep,
                  ),
                ),
              ),
              error: (_, _) => _emptyState(),
            ),
          ],
        )),
    );
  }

  Widget _buildContent(BrandConfig brand, List<CategoryMixRow> rows) {
    final totalRevenue = rows.fold<double>(0, (sum, r) => sum + r.revenue);

    return Column(
      children: [
        // Donut chart. The slices reach a radius of 80, so 180 is the drawing
        // plus a margin; the figure in the middle is measured against the same
        // box and must not be able to push past it.
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: rows.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final row = entry.value;
                    return PieChartSectionData(
                      value: row.revenue,
                      title: '',
                      color: _kSliceColors[idx % _kSliceColors.length],
                      radius: 30,
                    );
                  }).toList(),
                ),
              ),
              // Center total
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    brand.moneyLakh(totalRevenue),
                    style: AppType.titleM.copyWith(fontWeight: FontWeight.w800, color: AppColors.brandDeep),
                    maxLines: 1,
                  ),
                  Text(
                    'Total',
                    style: AppType.caption.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Ranked table
        ...rows.asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          return _MixRow(
            rank: idx + 1,
            color: _kSliceColors[idx % _kSliceColors.length],
            row: row,
          );
        }),
      ],
    );
  }

  // Padding, not a fixed height. An icon over a line of text inside a pinned
  // box overflows the moment the phone's font scale goes up a notch, which is
  // exactly the warning this was producing.
  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 32,
              color: AppColors.border,
            ),
            const SizedBox(height: 8),
            Text(
              'No revenue data for this period',
              style: AppType.label.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

}

class _MixRow extends ConsumerWidget {
  const _MixRow({required this.rank, required this.color, required this.row});

  final int rank;
  final Color color;
  final CategoryMixRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Color dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          // Emoji + Name
          Text(row.emoji, style: AppType.body),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              row.categoryName,
              style: AppType.label.copyWith(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Revenue
          Text(
            ref.watch(brandProvider).money(row.revenue.round()),
            style: AppType.label.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          // Share %
          SizedBox(
            width: 40,
            child: Text(
              '${row.sharePercent.toStringAsFixed(0)}%',
              style: AppType.caption.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          // Trend arrow
          SizedBox(width: 44, child: _buildTrend(row.trendPercent)),
        ],
      ),
    );
  }

  Widget _buildTrend(double? trend) {
    if (trend == null) {
      return Text(
        '—',
        style: AppType.caption.copyWith(color: AppColors.textTertiary),
        textAlign: TextAlign.right,
      );
    }
    return DeltaPill(
      value: trend,
      label: '${trend.abs().toStringAsFixed(0)}%',
      dense: true,
    );
  }
}
