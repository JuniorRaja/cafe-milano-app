import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/category_emoji.dart';
import '../ui/ui.dart';

class WeekdayHeatmapWidget extends ConsumerWidget {
  const WeekdayHeatmapWidget({super.key});

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapAsync = ref.watch(weekdayHeatmapProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return RepaintBoundary(
      child: AppCard(padding: const EdgeInsets.all(20), border: Border.all(color: AppColors.border), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('📅', style: AppType.titleM),
                SizedBox(width: 6),
                Text(
                  'Day-of-Week Heatmap',
                  style: AppType.titleS.copyWith(fontWeight: FontWeight.w700, color: AppColors.brandDeep),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Average pieces sold per weekday',
              style: AppType.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            heatmapAsync.when(
              data: (heatmap) {
                if (heatmap.isEmpty) return _emptyState();
                return categoriesAsync.when(
                  data: (cats) {
                    final catMap = <int?, String>{
                      for (final c in cats) c.id: c.name,
                    };
                    return _buildHeatmap(heatmap, catMap, context);
                  },
                  loading: () => _loading(),
                  error: (e, _) => _failedState(ref, e),
                );
              },
              loading: () => _loading(),
              // Not `_emptyState()`. This card told the owner "not enough data"
              // for a query that was throwing on every row, for every release
              // it has shipped in. A failure has to look like a failure.
              error: (e, _) => _failedState(ref, e),
            ),
          ],
        )),
    );
  }

  Widget _buildHeatmap(
    Map<int?, Map<int, double>> heatmap,
    Map<int?, String> catNames,
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
        final totalA = heatmap[a]!.values.fold<double>(0, (sum, v) => sum + v);
        final totalB = heatmap[b]!.values.fold<double>(0, (sum, v) => sum + v);
        return totalB.compareTo(totalA);
      });

    return Column(
      children: [
        // Header row with day labels
        Padding(
          padding: const EdgeInsets.only(left: 70),
          child: Row(
            children: _dayLabels
                .map(
                  (d) => Expanded(
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: AppType.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                )
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
                      Text(emoji, style: AppType.label),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          catName,
                          style: AppType.caption.copyWith(fontWeight: FontWeight.w500),
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
                          color: AppColors.brandPrimary.withValues(
                            alpha: 0.1 + (intensity * 0.8),
                          ),
                          borderRadius: AppRadius.rS,
                        ),
                        child: Center(
                          child: val > 0
                              ? Text(
                                  val.toStringAsFixed(0),
                                  style: AppType.caption.copyWith(fontWeight: FontWeight.w600, color: intensity > 0.5
                                        ? Colors.black87
                                        : AppColors.textSecondary),
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
            Icon(Icons.grid_on_rounded, size: 28, color: AppColors.border),
            const SizedBox(height: 6),
            Text(
              'No data for the selected period',
              style: AppType.label.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  /// Distinct from [_emptyState] on purpose, and the reason this card was
  /// broken in plain sight: "not enough data" and "the query failed" are
  /// different sentences and must not share a widget.
  Widget _failedState(WidgetRef ref, Object error) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 28,
              color: AppColors.negative,
            ),
            const SizedBox(height: AppSpace.s1),
            Text(
              'Could not build the heatmap.',
              style: AppType.bodyS.copyWith(color: AppColors.textSecondary),
            ),
            Text(
              '$error',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption.copyWith(color: AppColors.textTertiary),
            ),
            TextButton(
              onPressed: () => ref.invalidate(weekdayHeatmapProvider),
              child: const Text('Try again'),
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
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandDeep),
      ),
    );
  }
}
