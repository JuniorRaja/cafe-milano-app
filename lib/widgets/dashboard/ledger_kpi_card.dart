import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/brand_config.dart';
import '../../utils/money.dart';
import '../ui/ui.dart';

/// Billed vs Collected for the selected dashboard period.
/// Data comes from `dashboardPeriodMoneyProvider` which watches the period
/// picker — the card re-renders whenever the period changes.
class LedgerKpiCard extends ConsumerWidget {
  const LedgerKpiCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moneyAsync = ref.watch(dashboardPeriodMoneyProvider);
    final brand = ref.watch(brandProvider);

    return RepaintBoundary(
      child: AppCard(
        padding: const EdgeInsets.all(20),
        border: Border.all(color: AppColors.border),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🧾', style: AppType.titleM),
                const SizedBox(width: 6),
                Text(
                  'Period Finances',
                  style: AppType.titleS.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandDeep,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            moneyAsync.when(
              data: (money) => Row(
                children: [
                  _Stat(label: 'Billed', value: brand.money(money.billed)),
                  const SizedBox(width: AppSpace.s5),
                  _Stat(label: 'Collected', value: brand.money(money.collected)),
                  const SizedBox(width: AppSpace.s5),
                  _Stat(
                    label: 'Net',
                    value: brand.money(money.net.abs()),
                    valueColor: money.net >= 0
                        ? AppColors.positive
                        : AppColors.negative,
                  ),
                ],
              ),
              loading: () => const SizedBox(
                height: 40,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandDeep,
                  ),
                ),
              ),
              error: (e, s) => Text(
                'Could not load period finances',
                style: AppType.label.copyWith(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppType.titleS.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
