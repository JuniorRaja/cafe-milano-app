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
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s2),
        itemBuilder: (context, i) => _Chip(
          data: chips[i],
          selected: i == selectedIndex,
          onTap: () => onSelected(i),
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
              Text(data.label, style: AppType.label.copyWith(color: fg)),
              if (data.count != null) ...[
                const SizedBox(width: AppSpace.s1),
                Text(
                  '${data.count}',
                  style: AppType.label.copyWith(
                    color:
                        data.tone?.fg ??
                        (selected ? fg : AppColors.textTertiary),
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
