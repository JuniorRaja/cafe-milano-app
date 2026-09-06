import 'package:flutter/material.dart';
import '../ui/ui.dart';
import '../../theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../utils/money.dart';
import '../../theme/brand_config.dart';

class ProductLeaderboardCard extends ConsumerWidget {
  const ProductLeaderboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderAsync = ref.watch(productLeaderboardProvider);

    return RepaintBoundary(
      child: AppCard(padding: const EdgeInsets.all(20), border: Border.all(color: AppColors.border), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🏆', style: AppType.titleM),
                SizedBox(width: 6),
                Text(
                  'Product Leaderboard',
                  style: AppType.titleS.copyWith(fontWeight: FontWeight.w700, color: AppColors.brandDeep),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Top 10 products by revenue',
              style: AppType.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            leaderAsync.when(
              data: (rows) {
                if (rows.isEmpty) return _emptyState();
                return _buildTable(rows);
              },
              loading: () => const SizedBox(
                height: 100,
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

  Widget _buildTable(List<ProductLeaderRow> rows) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const SizedBox(width: 40), // rank + emoji space
              Expanded(
                child: Text(
                  'Product',
                  style: AppType.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'Revenue',
                  style: AppType.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  'Qty',
                  style: AppType.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  'Shops',
                  style: AppType.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        ...rows.asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          return _ProductRow(rank: idx + 1, row: row);
        }),
      ],
    );
  }

  // Padding, not a fixed height. An icon over a line of text inside a pinned
  // box overflows the moment the phone's font scale goes up a notch, which is
  // exactly the warning this was producing.
  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 28,
              color: AppColors.border,
            ),
            const SizedBox(height: 6),
            Text(
              'No product data for this period',
              style: AppType.label.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends ConsumerWidget {
  const _ProductRow({required this.rank, required this.row});
  final int rank;
  final ProductLeaderRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          // Rank + category emoji. 32 was not enough for a two-digit rank
          // beside a wide emoji, and the tenth row is the one this card
          // exists to show.
          SizedBox(
            width: 40,
            child: Row(
              children: [
                Text(
                  '$rank',
                  style: AppType.caption.copyWith(fontWeight: FontWeight.w700, color: rank <= 3 ? AppColors.brandDeep : AppColors.textSecondary),
                  maxLines: 1,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    row.categoryEmoji,
                    style: AppType.label,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          // Product name
          Expanded(
            child: Text(
              row.productName,
              style: AppType.label.copyWith(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Revenue
          SizedBox(
            width: 60,
            child: Text(
              brand.moneyLakh(row.revenue),
              style: AppType.caption.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
          // Qty
          SizedBox(
            width: 40,
            child: Text(
              brand.countLakh(row.qty),
              style: AppType.caption.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.right,
            ),
          ),
          // Shop count
          SizedBox(
            width: 36,
            child: Text(
              '${row.shopCount}',
              style: AppType.caption.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
