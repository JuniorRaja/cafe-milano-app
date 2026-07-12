import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/category_emoji.dart';

class WeekdayHeatmapWidget extends ConsumerWidget {
  const WeekdayHeatmapWidget({super.key});

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapAsync = ref.watch(weekdayHeatmapProvider);
    final scorecardsAsync = ref.watch(categoryScorecardsProvider);

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
              Text('📅', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text(
                'Day-of-Week Heatmap',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kBrandBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Average demand per category per weekday (4 weeks)',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          heatmapAsync.when(
            data: (heatmap) {
              if (heatmap.isEmpty) return _emptyState();
              return scorecardsAsync.when(
                data: (scorecards) =>
                    _buildHeatmap(heatmap, scorecards, context),
                loading: () => _loading(),
                error: (_, _) => _emptyState(),
              );
            },
            loading: () => _loading(),
            error: (_, _) => _emptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmap(
    Map<int?, Map<int, double>> heatmap,
    List scorecards,
    BuildContext context,
  ) {
    // Find global max for colour intensity
    double globalMax = 0;
    for (final dayMap in heatmap.values) {
      for (final val in dayMap.values) {
        if (val > globalMax) globalMax = val;
      }
    }
    if (globalMax == 0) globalMax = 1;

    // Sort categories by their heatmap total (descending)
    final sortedCatIds = heatmap.keys.toList()
      ..sort((a, b) {
        final totalA =
            heatmap[a]!.values.fold<double>(0, (sum, v) => sum + v);
        final totalB =
            heatmap[b]!.values.fold<double>(0, (sum, v) => sum + v);
        return totalB.compareTo(totalA);
      });

    // Build category name lookup from scorecards
    final catNames = <int?, String>{};
    for (final sc in scorecards) {
      catNames[sc.categoryId] = sc.categoryName;
    }

    return Column(
      children: [
        // Header row with day labels
        Padding(
          padding: const EdgeInsets.only(left: 70),
          child: Row(
            children: _dayLabels
                .map((d) => Expanded(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        // Category rows
        ...sortedCatIds.map((catId) {
          final catName = catNames[catId] ?? 'Others';
          final emoji = emojiFor(catName);
          final dayMap = heatmap[catId]!;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                // Category label
                SizedBox(
                  width: 70,
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          catName,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // 7 cells
                ...List.generate(7, (day) {
                  final val = dayMap[day] ?? 0;
                  final intensity = val / globalMax;
                  return Expanded(
                    child: Tooltip(
                      message: '${val.toStringAsFixed(0)} pcs',
                      child: Container(
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: kBrandGold.withValues(
                              alpha: 0.1 + (intensity * 0.8)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: val > 0
                              ? Text(
                                  val.toStringAsFixed(0),
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: intensity > 0.5
                                        ? Colors.black87
                                        : Colors.grey.shade700,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _emptyState() {
    return SizedBox(
      height: 80,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_on_rounded, size: 28, color: Colors.grey.shade300),
            const SizedBox(height: 6),
            Text(
              'Not enough data for heatmap (needs 4 weeks)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loading() {
    return const SizedBox(
      height: 100,
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: kBrandBrown),
      ),
    );
  }
}
