import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../models/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';

class ProductLeaderboardCard extends ConsumerWidget {
  const ProductLeaderboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderAsync = ref.watch(productLeaderboardProvider);

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
              Text('🏆', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text(
                'Product Leaderboard',
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
            'Top 10 products by revenue',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
                    strokeWidth: 2, color: kBrandBrown),
              ),
            ),
            error: (_, _) => _emptyState(),
          ),
        ],
      ),
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
              const SizedBox(width: 32), // rank + emoji space
              Expanded(
                child: Text(
                  'Product',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'Revenue',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  'Qty',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  'Shops',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
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

  Widget _emptyState() {
    return SizedBox(
      height: 80,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 28, color: Colors.grey.shade300),
            const SizedBox(height: 6),
            Text(
              'No product data for this period',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.rank, required this.row});
  final int rank;
  final ProductLeaderRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          // Rank + Category emoji
          SizedBox(
            width: 32,
            child: Row(
              children: [
                Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: rank <= 3 ? kBrandBrown : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 3),
                Text(row.categoryEmoji, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          // Product name
          Expanded(
            child: Text(
              row.productName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Revenue
          SizedBox(
            width: 60,
            child: Text(
              '₹${NumberFormat.compact().format(row.revenue)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Qty
          SizedBox(
            width: 40,
            child: Text(
              NumberFormat.compact().format(row.qty),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Shop count
          SizedBox(
            width: 36,
            child: Text(
              '${row.shopCount}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
