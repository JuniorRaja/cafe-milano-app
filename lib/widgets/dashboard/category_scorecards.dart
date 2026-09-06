import 'package:flutter/material.dart';
import '../ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';
import 'category_sparkline.dart';
import '../../utils/money.dart';
import '../../theme/brand_config.dart';

class CategoryScorecardsWidget extends ConsumerWidget {
  const CategoryScorecardsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scorecardsAsync = ref.watch(categoryScorecardsProvider);

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                const Text('📊', style: AppType.titleM),
                const SizedBox(width: 6),
                Text(
                  'Category Scorecards',
                  style: AppType.titleS.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandDeep,
                  ),
                ),
              ],
            ),
          ),
          scorecardsAsync.when(
            data: (scorecards) {
              if (scorecards.isEmpty) {
                return _emptyState();
              }
              return SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  itemCount: scorecards.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      _ScorecardCard(scorecard: scorecards[index]),
                ),
              );
            },
            loading: () => SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, _) => _loadingCard(),
              ),
            ),
            error: (_, _) => _emptyState(),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return SizedBox(
      height: 120,
      child: AppCard(
        border: Border.all(color: AppColors.border),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.category_outlined, size: 32, color: AppColors.border),
              const SizedBox(height: 8),
              Text(
                'No category data yet',
                style: AppType.bodyS.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _loadingCard() {
    // 160 wide, because this scrolls horizontally. `AppCard` sizes to its
    // child and a horizontal ListView gives unbounded width, so dropping this
    // collapsed the card to nothing.
    return SizedBox(
      width: 160,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        border: Border.all(color: AppColors.border),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 14,
              width: 80,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: AppRadius.rS,
              ),
            ),
            const Spacer(),
            Container(
              height: 20,
              width: 60,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: AppRadius.rS,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorecardCard extends ConsumerWidget {
  const _ScorecardCard({required this.scorecard});
  final CategoryScorecard scorecard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    // Same 160 as the loading card: this row scrolls sideways.
    return SizedBox(
      width: 160,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        border: Border.all(color: AppColors.border),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji + Name
            Row(
              children: [
                Text(scorecard.emoji, style: AppType.titleM),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    scorecard.categoryName,
                    style: AppType.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandDeep,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Revenue
            Text(
              brand.moneyLakh(scorecard.revenue),
              style: AppType.titleM.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.brandDeep,
              ),
            ),
            const SizedBox(height: 4),

            // Volume + Reach
            Text(
              '${brand.count(scorecard.pieces)} pcs · ${scorecard.shopCount} shops',
              style: AppType.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),

            // Sparkline
            CategorySparkline(
              data: scorecard.sparklineData,
              width: 130,
              height: 32,
            ),
            const SizedBox(height: 8),

            // Star Product
            if (scorecard.starProductName != null)
              Row(
                children: [
                  Icon(Icons.star_rounded, size: 12, color: AppColors.warning),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      '${scorecard.starProductName} (${scorecard.starProductSharePercent.toStringAsFixed(0)}%)',
                      style: AppType.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else
              Text(
                'No sales yet',
                style: AppType.caption.copyWith(color: AppColors.textTertiary),
              ),
          ],
        ),
      ),
    );
  }
}
