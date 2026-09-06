import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/dashboard_provider.dart';
import '../../theme/brand_config.dart';
import '../../utils/money.dart';
import '../ui/ui.dart';

/// Today, as one figure.
///
/// This was a 2×2 grid of four equally-weighted tiles, which meant the day's
/// revenue — the number the card exists to show — had exactly the same visual
/// weight as the count of pending confirmations. Doc 10c: the Pulse becomes a
/// [HeroStatCard], so there is one `displayL` on the screen and everything
/// else supports it.
///
/// Revenue is the value, last week's comparison is the trailing [DeltaPill],
/// and the two secondary counts move into the footer.
class PulseCard extends ConsumerWidget {
  const PulseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    final revenueAsync = ref.watch(todayRevenueProvider);
    final deltaAsync = ref.watch(revenueDeltaProvider);
    final shopsAsync = ref.watch(shopsServedTodayProvider);
    final pendingAsync = ref.watch(pendingConfirmationsProvider);

    final pending = pendingAsync.valueOrNull;

    return RepaintBoundary(
      child: HeroStatCard(
        caption: "Today's revenue",
        value: revenueAsync.when(
          data: brand.moneyLakh,
          loading: () => '—',
          // Distinct from a real zero: a failed query must never render as
          // a revenue figure. See 10c Phase 3.
          error: (_, _) => 'Unavailable',
        ),
        subtitle: 'vs the same day last week',
        trailing: deltaAsync.when(
          data: (delta) => delta == null
              ? const SizedBox.shrink()
              : DeltaPill(
                  value: delta,
                  label: '${delta.abs().toStringAsFixed(0)}%',
                ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        // The margin is zero because the dashboard's own Column already pays
        // the page gutter; the card's default would pay it twice.
        margin: EdgeInsets.zero,
        footer: Row(
          children: [
            Expanded(
              child: _Footnote(
                label: 'Shops served',
                value: shopsAsync.when(
                  data: (data) => '${data.$1} / ${data.$2}',
                  loading: () => '—',
                  error: (_, _) => '—',
                ),
              ),
            ),
            Expanded(
              child: _Footnote(
                label: 'Pending confirmations',
                value: pending == null ? '—' : '$pending',
                // Semantic, not decorative: amber only when something is
                // actually waiting on the owner.
                tone: (pending ?? 0) > 0 ? AppTone.warning : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One supporting count under the hero figure, on the dark ground.
class _Footnote extends StatelessWidget {
  const _Footnote({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final AppTone? tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AppType.caption.copyWith(
            color: AppColors.textOnDark.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: AppSpace.s1),
        Text(
          value,
          style: AppType.titleM.copyWith(
            color: tone == null ? AppColors.textOnDark : tone!.fg,
          ),
        ),
      ],
    );
  }
}
