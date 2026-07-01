import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app.dart';
import '../database/app_database.dart';
import 'letter_avatar.dart';

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
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LetterAvatar(name: shop.name),
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
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 13, color: Colors.grey[500]),
                              const SizedBox(width: 2),
                              Text(
                                shop.area!,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  _StatusChip(
                    label: isConfirmed ? 'Confirmed' : 'Pending',
                    color: isConfirmed ? Colors.green : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (hasOrder) ...[
                Row(
                  children: [
                    _BrandChip(label: '${summary!.itemCount} items'),
                    const SizedBox(width: 6),
                    _BrandChip(
                        label:
                            '₹${NumberFormat('#,##0').format(summary!.total)}'),
                  ],
                ),
              ] else ...[
                Text(
                  'Tap to add order',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
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

class _BrandChip extends StatelessWidget {
  const _BrandChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBrandCrimson.withAlpha(80), width: 0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kBrandCrimson,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
