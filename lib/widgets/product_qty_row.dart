import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
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
    this.onDecrementHold,
    this.onIncrementHold,
    this.onQtySet,
  });

  final Product product;
  final int qty;
  final double? price;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrementHold;
  final VoidCallback? onIncrementHold;
  final ValueChanged<int>? onQtySet;

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
                _StepperBtn(
                  icon: Icons.remove,
                  onPressed: onDecrement,
                  onLongPressTick: onDecrementHold,
                ),
                GestureDetector(
                  onTap: onQtySet != null
                      ? () => _showQtyModal(context)
                      : null,
                  child: SizedBox(
                    width: 40,
                    child: Text(
                      qty.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                _StepperBtn(
                  icon: Icons.add,
                  onPressed: onIncrement,
                  onLongPressTick: onIncrementHold,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQtyModal(BuildContext context) {
    unawaited(showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _QtyEditSheet(
        product: product,
        initialQty: qty,
        onConfirm: onQtySet!,
      ),
    ));
  }
}

class _QtyEditSheet extends StatefulWidget {
  const _QtyEditSheet({
    required this.product,
    required this.initialQty,
    required this.onConfirm,
  });

  final Product product;
  final int initialQty;
  final ValueChanged<int> onConfirm;

  @override
  State<_QtyEditSheet> createState() => _QtyEditSheetState();
}

class _QtyEditSheetState extends State<_QtyEditSheet> {
  bool _useInput = false;
  int _wheelGeneration = 0;
  late int _hundreds;
  late int _tens;
  late int _ones;
  late final TextEditingController _ctrl;

  int get _wheelValue => _hundreds * 100 + _tens * 10 + _ones;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialQty.clamp(0, 999);
    _hundreds = seed ~/ 100;
    _tens = (seed % 100) ~/ 10;
    _ones = seed % 10;
    _ctrl = TextEditingController(text: widget.initialQty.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _switchTo(bool useInput) {
    setState(() {
      if (useInput) {
        _ctrl.text = _wheelValue.toString();
        _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
      } else {
        final seed = (int.tryParse(_ctrl.text) ?? 0).clamp(0, 999);
        _hundreds = seed ~/ 100;
        _tens = (seed % 100) ~/ 10;
        _ones = seed % 10;
        _wheelGeneration++; // forces the wheels to rebuild seeded at the new value
      }
      _useInput = useInput;
    });
  }

  void _confirm() {
    final value = _useInput
        ? (int.tryParse(_ctrl.text) ?? 0).clamp(0, 9999)
        : _wheelValue;
    widget.onConfirm(value);
    Navigator.pop(context);
  }

  Widget _digitWheel({
    required Key key,
    required int initial,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      key: key,
      width: 56,
      child: CupertinoPicker.builder(
        itemExtent: 40,
        scrollController: FixedExtentScrollController(initialItem: initial),
        onSelectedItemChanged: (i) {
          unawaited(HapticFeedback.lightImpact());
          onChanged(i);
        },
        childCount: 10,
        itemBuilder: (_, i) => Center(
          child: Text(
            '$i',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.product.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Wheel')),
              ButtonSegment(value: true, label: Text('Input')),
            ],
            selected: {_useInput},
            onSelectionChanged: (s) => _switchTo(s.first),
          ),
          const SizedBox(height: 16),
          if (_useInput)
            TextField(
              controller: _ctrl,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _digitWheel(
                      key: ValueKey('h$_wheelGeneration'),
                      initial: _hundreds,
                      onChanged: (v) => _hundreds = v,
                    ),
                    _digitWheel(
                      key: ValueKey('t$_wheelGeneration'),
                      initial: _tens,
                      onChanged: (v) => _tens = v,
                    ),
                    _digitWheel(
                      key: ValueKey('o$_wheelGeneration'),
                      initial: _ones,
                      onChanged: (v) => _ones = v,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _confirm,
              child: const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperBtn extends StatefulWidget {
  const _StepperBtn({required this.icon, this.onPressed, this.onLongPressTick});

  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPressTick;

  @override
  State<_StepperBtn> createState() => _StepperBtnState();
}

class _StepperBtnState extends State<_StepperBtn> {
  bool _pressed = false;
  Timer? _repeatTimer;

  void _startRepeat() {
    final tick = widget.onLongPressTick;
    if (tick == null) return;
    unawaited(HapticFeedback.lightImpact());
    tick();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      unawaited(HapticFeedback.lightImpact());
      widget.onLongPressTick?.call();
    });
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.onPressed != null;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return GestureDetector(
      onLongPressStart:
          isActive && widget.onLongPressTick != null ? (_) => _startRepeat() : null,
      onLongPressEnd: (_) => _stopRepeat(),
      onLongPressCancel: _stopRepeat,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isActive
            ? () {
                unawaited(HapticFeedback.lightImpact());
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
      ),
    );
  }
}
