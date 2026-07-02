import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../app.dart';
import '../database/app_database.dart';
import 'letter_avatar.dart';

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
            SizedBox(
              width: 48,
              height: 48,
              child: product.photoPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(product.photoPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            LetterAvatar(name: product.name),
                      ),
                    )
                  : LetterAvatar(name: product.name),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
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
                  width: 40,
                  child: Text(
                    qty.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
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
}

class _StepperBtn extends StatefulWidget {
  const _StepperBtn({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  State<_StepperBtn> createState() => _StepperBtnState();
}

class _StepperBtnState extends State<_StepperBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.onPressed != null;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: isActive
          ? () {
              HapticFeedback.lightImpact();
              widget.onPressed!();
            }
          : null,
      onHighlightChanged:
          isActive ? (v) => setState(() => _pressed = v) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 100),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? kBrandBrown : Colors.grey.withAlpha(40),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: isActive ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }
}
