import 'package:flutter/material.dart';
import '../../theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dashboard_provider.dart';
import '../../utils/money.dart';
import '../../theme/brand_config.dart';

class PulseCard extends ConsumerWidget {
  const PulseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    final revenueAsync = ref.watch(todayRevenueProvider);
    final deltaAsync = ref.watch(revenueDeltaProvider);
    final shopsAsync = ref.watch(shopsServedTodayProvider);
    final pendingAsync = ref.watch(pendingConfirmationsProvider);

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.rM,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('❤️', style: AppType.titleM),
                const SizedBox(width: 8),
                Text(
                  'The Pulse',
                  style: AppType.titleM.copyWith(fontWeight: FontWeight.w700, color: AppColors.brandDeep),
                ),
                const Spacer(),
                Text(
                  'Today',
                  style: AppType.caption.copyWith(fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 2×2 metric grid
            Row(
              children: [
                // Revenue
                Expanded(
                  child: _MetricTile(
                    label: "Today's Revenue",
                    child: revenueAsync.when(
                      data: (rev) => Text(
                        brand.moneyLakh(rev),
                        style: AppType.titleL.copyWith(fontWeight: FontWeight.w800, color: AppColors.brandDeep),
                      ),
                      loading: () => _shimmer(),
                      error: (_, _) => const Text('—'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Delta
                Expanded(
                  child: _MetricTile(
                    label: 'vs Same Day Last Week',
                    child: deltaAsync.when(
                      data: (delta) => _buildDelta(delta),
                      loading: () => _shimmer(),
                      error: (_, _) => const Text('—'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Shops served
                Expanded(
                  child: _MetricTile(
                    label: 'Shops Served',
                    child: shopsAsync.when(
                      data: (data) => Text(
                        '${data.$1} / ${data.$2} shops',
                        style: AppType.titleM.copyWith(fontWeight: FontWeight.w700, color: AppColors.brandDeep),
                      ),
                      loading: () => _shimmer(),
                      error: (_, _) => const Text('—'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Pending
                Expanded(
                  child: _MetricTile(
                    label: 'Pending Confirmations',
                    child: pendingAsync.when(
                      data: (count) => Text(
                        '$count pending',
                        style: AppType.titleM.copyWith(fontWeight: FontWeight.w700, color: count > 0
                              ? Colors.amber.shade700
                              : AppColors.brandDeep),
                      ),
                      loading: () => _shimmer(),
                      error: (_, _) => const Text('—'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDelta(double? delta) {
    if (delta == null) {
      return Text(
        '→ 0%',
        style: AppType.titleM.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
      );
    }
    final isUp = delta >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 18,
          color: isUp ? Colors.green.shade600 : Colors.red.shade600,
        ),
        const SizedBox(width: 2),
        Text(
          '${delta.abs().toStringAsFixed(0)}%',
          style: AppType.titleM.copyWith(fontWeight: FontWeight.w700, color: isUp ? Colors.green.shade600 : Colors.red.shade600),
        ),
      ],
    );
  }

  static Widget _shimmer() {
    return Container(
      height: 20,
      width: 60,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: AppRadius.rS,
      ),
    );
  }

}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: AppRadius.rS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppType.caption.copyWith(fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
