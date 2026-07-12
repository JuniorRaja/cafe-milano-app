import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../models/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';
import 'category_sparkline.dart';

class CategoryScorecardsWidget extends ConsumerWidget {
  const CategoryScorecardsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scorecardsAsync = ref.watch(categoryScorecardsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              const Text(
                'Category Scorecards',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kBrandBrown,
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
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined, size: 32, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'No category data yet',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _loadingCard() {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 14,
            width: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Spacer(),
          Container(
            height: 20,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorecardCard extends StatelessWidget {
  const _ScorecardCard({required this.scorecard});
  final CategoryScorecard scorecard;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji + Name
          Row(
            children: [
              Text(scorecard.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  scorecard.categoryName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kBrandBrown,
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
            '₹${_formatRevenue(scorecard.revenue)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kBrandBrown,
            ),
          ),
          const SizedBox(height: 4),

          // Volume + Reach
          Text(
            '${NumberFormat('#,###').format(scorecard.pieces)} pcs · ${scorecard.shopCount} shops',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
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
                Icon(Icons.star_rounded,
                    size: 12, color: Colors.amber.shade600),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    '${scorecard.starProductName} (${scorecard.starProductSharePercent.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
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
              style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
            ),
        ],
      ),
    );
  }

  String _formatRevenue(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return NumberFormat('#,##,###').format(amount.round());
    }
    return amount.toStringAsFixed(0);
  }
}
