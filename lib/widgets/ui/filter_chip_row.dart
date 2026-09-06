import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// One chip in a [FilterChipRow].
class FilterChipData {
  const FilterChipData(this.label, {this.count, this.tone});

  final String label;

  /// Shown as a small counter after the label: `Needs Review 2`.
  final int? count;

  /// Colours the *count* only, so `Needs Review 2` can read as a warning while
  /// the chip itself stays neutral. Leave null for no meaning.
  final AppTone? tone;
}

/// A scrollable row of single-select filter chips:
/// `All Shops 18 · Needs Review 2 · Unbilled 4`. Replaces the ad-hoc chip rows
/// each screen grew its own version of.
///
/// Single-select on purpose. Multi-select filtering belongs in a sheet, not in
/// a row the user has to scroll to read.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.chips,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpace.s4,
      vertical: AppSpace.s2,
    ),
  });

  final List<FilterChipData> chips;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Space around the row. The horizontal half goes *inside* the scroll view,
  /// so the first chip starts on the page gutter and the last one can scroll
  /// past it. The vertical half goes outside — see [rowHeight].
  final EdgeInsetsGeometry padding;

  /// The height of the strip the chips are laid out in.
  ///
  /// **This was 40 and the labels were cut in half on Products.** The whole of
  /// [padding] used to go to the `ListView`, and in a horizontal list the
  /// vertical padding comes off the cross axis: 40 − 8 − 8 left each chip 24px,
  /// the chip's own 8+8 left 8px for the text, and a 12px label needs 14.4px.
  /// The engine clipped it, top and bottom, which is exactly what it looked
  /// like. The vertical padding now sits outside this box, where it separates
  /// the row from its neighbours instead of eating it.
  static const rowHeight = 44.0;

  /// The chip label's line height, in place of `AppType.label`'s 1.2.
  ///
  /// The padding above was what cut the labels. This is the second squeeze
  /// behind it: 1.2 at 12px is a 14.4px line box, and a colour emoji comes from
  /// a fallback font whose glyphs fill about that much on their own, so
  /// `🥐 Puffs` had nothing to spare either.
  ///
  /// It is fixed here and not on `AppType.label`, which is right at every other
  /// call site — none of them put an emoji in a 12px step.
  static const _labelHeight = 1.5;

  @override
  Widget build(BuildContext context) {
    final gutter = padding.resolve(Directionality.of(context));

    return Padding(
      padding: EdgeInsets.only(top: gutter.top, bottom: gutter.bottom),
      child: SizedBox(
        height: rowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(left: gutter.left, right: gutter.right),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s2),
          itemBuilder: (context, i) => _Chip(
            data: chips[i],
            selected: i == selectedIndex,
            onTap: () => onSelected(i),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final FilterChipData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.brandOnPrimary : AppColors.textSecondary;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rFull,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandPrimary : AppColors.surface,
            borderRadius: AppRadius.rFull,
            border: Border.all(
              color: selected ? AppColors.brandPrimary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.label,
                style: AppType.label.copyWith(
                  color: fg,
                  height: FilterChipRow._labelHeight,
                ),
              ),
              if (data.count != null) ...[
                const SizedBox(width: AppSpace.s1),
                Text(
                  '${data.count}',
                  style: AppType.label.copyWith(
                    color:
                        data.tone?.fg ??
                        (selected ? fg : AppColors.textTertiary),
                    height: FilterChipRow._labelHeight,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
