import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/haptics.dart';
import '../database/app_database.dart';
import 'letter_avatar.dart';
import '../utils/money.dart';
import '../theme/brand_config.dart';
import 'ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductQtyRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    final hasPrce = price != null;
    final lineTotal = hasPrce ? qty * price! : 0.0;
    final unitLabel = product.unit != null ? ' / ${product.unit}' : '';
    final priceLabel = hasPrce
        ? '${brand.moneyTrim(price!)}$unitLabel'
        : 'Price not set';

    final row = Padding(
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
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPrce
                      ? '$priceLabel  ·  ${brand.moneyTrim(lineTotal)}'
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
              SizedBox(
                width: 40,
                child: Text(
                  qty.toString(),
                  textAlign: TextAlign.center,
                  style: AppType.displayL.copyWith(
                    color: qty == 0 ? AppColors.textTertiary : null,
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
    );

    // The whole row opens the quantity sheet, not just the 40px number between
    // the steppers. That target was a thumb-width short of usable at 5 a.m.,
    // and the row is already the thing the eye is aiming at.
    //
    // The steppers keep working in place: they are children, so they win the
    // hit test and a tap on + never also opens the sheet.
    return Opacity(
      opacity: hasPrce ? 1.0 : 0.45,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onQtySet == null ? null : () => _showQtyModal(context),
          child: row,
        ),
      ),
    );
  }

  void _showQtyModal(BuildContext context) {
    unawaited(
      showModalBottomSheet(
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
      ),
    );
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
    // Empty at zero, not "0". The field used to be seeded with the literal
    // string, so typing 5 into a row at zero gave 50 or 05 depending on where
    // the caret happened to sit. The zero is a hint now — see [_qtyText].
    _ctrl = TextEditingController(text: _qtyText(widget.initialQty));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// What the input field shows for [qty]: nothing at zero, so the hint can.
  static String _qtyText(int qty) => qty == 0 ? '' : '$qty';

  void _switchTo(bool useInput) {
    setState(() {
      if (useInput) {
        _ctrl.text = _qtyText(_wheelValue);
        // Selected, not a caret at the end: on a row that already has a
        // quantity the next thing typed is a replacement, not a digit appended
        // to what is there.
        _ctrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _ctrl.text.length,
        );
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
    // An empty field is zero, not "leave it alone". `tryParse` returning null
    // is the empty case and it lands on the same branch as a typed 0.
    final value = _useInput
        ? (int.tryParse(_ctrl.text) ?? 0).clamp(0, 9999)
        : _wheelValue;
    widget.onConfirm(value);
    Navigator.pop(context);
  }

  /// Row height, and the height of the selection band across all three wheels.
  ///
  /// Was 40 in a 120-tall box 56 wide, which is a swipe target narrower than a
  /// thumb showing one neighbour either side. iOS wheels are taller and wider
  /// than that for a reason: you aim at the band, not at the digit.
  static const _itemExtent = 48.0;
  static const _wheelWidth = 72.0;
  static const _wheelHeight = 200.0;

  Widget _digitWheel({
    required Key key,
    required int initial,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      key: key,
      width: _wheelWidth,
      child: CupertinoPicker.builder(
        itemExtent: _itemExtent,
        scrollController: FixedExtentScrollController(initialItem: initial),
        // The band is drawn once behind all three wheels rather than three
        // times, so it reads as one control instead of three.
        selectionOverlay: const SizedBox.shrink(),
        onSelectedItemChanged: (i) {
          unawaited(AppHaptics.tap());
          onChanged(i);
        },
        childCount: 10,
        itemBuilder: (_, i) =>
            Center(child: Text('$i', style: AppType.displayL)),
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
          Text(widget.product.name, style: AppType.titleM),
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
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppType.displayL,
              decoration: InputDecoration(
                // Ghost, not a value. An empty field confirms as 0 either way,
                // so the hint says what will happen without pretending it has
                // already been typed.
                hintText: '0',
                hintStyle: AppType.displayL.copyWith(
                  color: AppColors.textTertiary,
                ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            )
          else
            // Centred. The column is left-aligned so the product name and the
            // Wheel/Input toggle start on the same edge, and the wheel block
            // is the one child narrow enough to sit off to one side of it.
            Center(
              child: SizedBox(
                height: _wheelHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: _itemExtent,
                      width: _wheelWidth * 3,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: AppRadius.rS,
                      ),
                    ),
                    Row(
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
    unawaited(AppHaptics.tap());
    tick();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      unawaited(AppHaptics.tap());
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
      onLongPressStart: isActive && widget.onLongPressTick != null
          ? (_) => _startRepeat()
          : null,
      onLongPressEnd: (_) => _stopRepeat(),
      onLongPressCancel: _stopRepeat,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isActive
            ? () {
                unawaited(AppHaptics.tap());
                widget.onPressed!();
              }
            : null,
        onHighlightChanged: isActive
            ? (v) => setState(() => _pressed = v)
            : null,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 100),
          // No fill. Twenty-eight rows, two steppers each, was fifty-six
          // filled brown boxes on the busiest screen in the app — the owner
          // asked for the background off so the row reads as a product and a
          // number rather than as a control panel.
          //
          // Nothing else changes: still a 36x36 target, still the press scale,
          // still doc 08's 400 ms long-press repeat. Disabled stays visibly
          // disabled rather than becoming an invisible target.
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              widget.icon,
              size: 22,
              color: isActive ? AppColors.brandDeep : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
