import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../models/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';

class ShopConcentrationCard extends ConsumerWidget {
  const ShopConcentrationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concAsync = ref.watch(shopConcentrationProvider);

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
              Text('🏪', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text(
                'Shop Concentration',
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
            'Top 5 shops by revenue',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 14),
          concAsync.when(
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

  Widget _buildTable(List<ShopConcentrationRow> rows) {
    return Column(
      children: rows.asMap().entries.map((entry) {
        final idx = entry.key;
        final row = entry.value;
        return _ShopRow(rank: idx + 1, row: row);
      }).toList(),
    );
  }

  Widget _emptyState() {
    return SizedBox(
      height: 80,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_outlined, size: 28, color: Colors.grey.shade300),
            const SizedBox(height: 6),
            Text(
              'No shop data for this period',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({required this.rank, required this.row});
  final int rank;
  final ShopConcentrationRow row;

  @override
  Widget build(BuildContext context) {
    final isHighConcentration = row.sharePercent > 25;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? kBrandBrown.withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: rank <= 3 ? kBrandBrown : Colors.grey.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Shop info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.shopName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (row.area != null)
                  Text(
                    row.area!,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          // Category breadth emojis
          SizedBox(
            width: 60,
            child: Text(
              row.categoryEmojis.take(4).join(''),
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          // Revenue + share
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${NumberFormat('#,##,###').format(row.revenue.round())}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isHighConcentration)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 10,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  Text(
                    '${row.sharePercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isHighConcentration
                          ? Colors.orange.shade700
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
