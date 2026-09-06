import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// A small dropdown sized to sit in a [SectionHeader]'s trailing slot, or
/// beside a screen's date line.
///
/// It replaced the dashboard's scrolling row of seven pills. A pill row cannot
/// sit next to a title, and the one that existed was wired straight into the
/// dashboard's own range — so the Ledger could not reuse it without the two
/// screens moving each other's period. This is the control both use, each with
/// its own state.
class HeaderMenu<T> extends StatelessWidget {
  const HeaderMenu({
    super.key,
    required this.label,
    required this.tooltip,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
    this.icon = Icons.expand_more_rounded,
  });

  /// What the closed control reads — normally the selected value's own label.
  final String label;

  final String tooltip;
  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;

  /// `expand_more` for a picker, `swap_vert` for a sort.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final value in values)
          CheckedPopupMenuItem<T>(
            value: value,
            checked: value == selected,
            child: Text(labelOf(value)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppType.label.copyWith(color: AppColors.brandDeep),
            ),
            const SizedBox(width: 2),
            Icon(icon, size: 18, color: AppColors.brandDeep),
          ],
        ),
      ),
    );
  }
}
