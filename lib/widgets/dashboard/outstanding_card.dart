import 'package:flutter/material.dart';
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
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(AppRoutes.outstanding),
        child: Container(
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
                  Text('💰', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text(
                    'Outstanding Receivables',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kBrandBrown,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right, size: 20, color: Colors.grey),
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
                          color: Colors.green.shade400,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Every shop is settled up.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.watch(brandProvider).money(total),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'owed by ${shops.length} ${shops.length == 1 ? 'shop' : 'shops'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 56,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kBrandBrown,
                    ),
                  ),
                ),
                error: (e, _) => Text(
                  'Could not load receivables',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
