import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../models/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';

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
    final mixAsync = ref.watch(categoryMixProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🍩', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text(
                'Category Revenue Mix',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kBrandBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          mixAsync.when(
            data: (rows) {
              if (rows.isEmpty) return _emptyState();
              return _buildContent(rows);
            },
            loading: () => const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kBrandBrown,
                ),
              ),
            ),
            error: (_, _) => _emptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<CategoryMixRow> rows) {
    final totalRevenue = rows.fold<double>(0, (sum, r) => sum + r.revenue);

    return Column(
      children: [
        // Donut Chart
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
                    '₹${_formatCurrency(totalRevenue)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kBrandBrown,
                    ),
                  ),
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
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

  Widget _emptyState() {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart_outline, size: 32, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'No revenue data for this period',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return NumberFormat('#,##,###').format(amount.round());
    }
    return amount.toStringAsFixed(0);
  }
}

class _MixRow extends StatelessWidget {
  const _MixRow({
    required this.rank,
    required this.color,
    required this.row,
  });

  final int rank;
  final Color color;
  final CategoryMixRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Color dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // Emoji + Name
          Text(row.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              row.categoryName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Revenue
          Text(
            '₹${NumberFormat('#,##,###').format(row.revenue.round())}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          // Share %
          SizedBox(
            width: 40,
            child: Text(
              '${row.sharePercent.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          // Trend arrow
          SizedBox(
            width: 44,
            child: _buildTrend(row.trendPercent),
          ),
        ],
      ),
    );
  }

  Widget _buildTrend(double? trend) {
    if (trend == null) {
      return Text(
        '—',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
        textAlign: TextAlign.right,
      );
    }
    final isUp = trend >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(
          isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 12,
          color: isUp ? Colors.green.shade600 : Colors.red.shade600,
        ),
        Text(
          '${trend.abs().toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isUp ? Colors.green.shade600 : Colors.red.shade600,
          ),
        ),
      ],
    );
  }
}
