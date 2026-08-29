import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// One item in a [StatBand].
class StatBandItem {
  const StatBandItem(this.value, {this.label, this.tone = AppTone.neutral});

  /// The already-formatted figure: `16/18 shops`, `₹24,680`. Format money
  /// through `BrandConfig.money`.
  final String value;

  /// Optional word under the figure.
  final String? label;

  /// Semantic only. Leave neutral unless the figure means something is wrong.
  final AppTone tone;
}

/// A thin strip of headline figures under a screen header:
/// `16/18 shops · ₹24,680 · ↑8%`. New — there was nowhere in the app that
/// summarised a list before you scrolled it.
///
/// Pass [trailing] for a [DeltaPill] or any other widget at the end.
class StatBand extends StatelessWidget {
  const StatBand({
    super.key,
    required this.items,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.s4,
      AppSpace.s2,
      AppSpace.s4,
      AppSpace.s2,
    ),
  });

  final List<StatBandItem> items;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.s2),
            child: Text('·', style: AppType.body),
          ),
        );
      }
      children.add(_Item(item: items[i]));
    }

    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s3,
          vertical: AppSpace.s2,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: AppRadius.rS,
        ),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: children),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpace.s2),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item});

  final StatBandItem item;

  @override
  Widget build(BuildContext context) {
    final colour = item.tone == AppTone.neutral
        ? AppColors.textPrimary
        : item.tone.fg;

    if (item.label == null) {
      return Text(item.value, style: AppType.titleS.copyWith(color: colour));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(item.value, style: AppType.titleS.copyWith(color: colour)),
        const SizedBox(width: AppSpace.s1),
        Text(
          item.label!,
          style: AppType.bodyS.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
