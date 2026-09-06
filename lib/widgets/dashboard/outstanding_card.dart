import 'package:flutter/material.dart';
import '../ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../providers/ledger_provider.dart';
import '../../utils/money.dart';
import '../../theme/brand_config.dart';

/// Total cash owed across every shop, and a way into the list behind it.
///
/// The figure is the sum of exactly the rows [OutstandingListScreen] shows —
/// one query, summed once — so the headline and the list are the same number
/// by construction rather than by two computations agreeing.
class OutstandingCard extends ConsumerWidget {
  const OutstandingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(outstandingByShopProvider);

    return RepaintBoundary(
      child: InkWell(
        borderRadius: AppRadius.rM,
        onTap: () => context.push(AppRoutes.outstanding),
        child: AppCard(padding: const EdgeInsets.all(20), border: Border.all(color: AppColors.border), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('💰', style: AppType.titleM),
                  SizedBox(width: 6),
                  Text(
                    'Outstanding Receivables',
                    style: AppType.titleS.copyWith(fontWeight: FontWeight.w700, color: AppColors.brandDeep),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
                ],
              ),
              const SizedBox(height: 14),
              shopsAsync.when(
                data: (shops) {
                  final total = shops.fold<double>(
                    0,
                    (sum, s) => sum + s.outstanding,
                  );
                  if (shops.isEmpty) {
                    return Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 20,
                          color: AppColors.positive,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Every shop is settled up.',
                          style: AppType.bodyS.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.watch(brandProvider).money(total),
                        style: AppType.displayL.copyWith(fontWeight: FontWeight.w800, color: AppColors.negative),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'owed by ${shops.length} ${shops.length == 1 ? 'shop' : 'shops'}',
                        style: AppType.label.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 56,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandDeep,
                    ),
                  ),
                ),
                error: (e, _) => Text(
                  'Could not load receivables',
                  style: AppType.label.copyWith(color: AppColors.textTertiary),
                ),
              ),
            ],
          )),
      ),
    );
  }
}
