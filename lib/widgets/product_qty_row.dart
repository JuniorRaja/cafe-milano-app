import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';

class ProductQtyRow extends StatelessWidget {
  const ProductQtyRow({
    super.key,
    required this.product,
    required this.qty,
    this.price,
    this.onDecrement,
    this.onIncrement,
  });

  final Product product;
  final int qty;
  final double? price;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final hasPrce = price != null;
    final lineTotal = hasPrce ? qty * price! : 0.0;
    final unitLabel = product.unit != null ? ' / ${product.unit}' : '';
    final priceLabel = hasPrce
        ? '₹${NumberFormat('#,##0.##').format(price)}$unitLabel'
        : 'Price not set';

    return Opacity(
      opacity: hasPrce ? 1.0 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: product.photoPath != null
                    ? Image.file(
                        File(product.photoPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasPrce
                        ? '$priceLabel  ·  ₹${NumberFormat('#,##0.##').format(lineTotal)}'
                        : 'Price not set',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepperBtn(icon: Icons.remove, onPressed: onDecrement),
                SizedBox(
                  width: 36,
                  child: Text(
                    qty.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                _StepperBtn(icon: Icons.add, onPressed: onIncrement),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFFFF3E0),
        child: const Icon(Icons.bakery_dining, color: Color(0xFFF57C00), size: 28),
      );
}

class _StepperBtn extends StatelessWidget {
  const _StepperBtn({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: onPressed != null
              ? const Color(0xFFF57C00).withAlpha(25)
              : Colors.grey.withAlpha(20),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
