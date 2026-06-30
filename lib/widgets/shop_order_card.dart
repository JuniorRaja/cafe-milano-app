import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';

class ShopOrderCard extends StatelessWidget {
  const ShopOrderCard({
    super.key,
    required this.shop,
    required this.summary,
    required this.onTap,
  });

  final Shop shop;
  final OrderDaySummary? summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasOrder = summary != null;
    final isConfirmed = summary?.order.isConfirmed ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFF57C00),
                child: const Icon(Icons.storefront, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (shop.area != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        shop.area!,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (hasOrder) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _StatusChip(
                            label: isConfirmed ? 'Confirmed' : 'Pending',
                            color: isConfirmed ? Colors.green : Colors.grey,
                          ),
                          _StatusChip(
                            label:
                                '${summary!.itemCount} items · ₹${NumberFormat('#,##0').format(summary!.total)}',
                            color: const Color(0xFFF57C00),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Tap to add order',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
