import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The app's list row. Replaces `ShopOrderCard` and six near-identical
/// copies of it — the shop row, the product row, the category row, the ledger
/// row, the outstanding row, the at-risk row.
///
/// The row wraps itself in a [RepaintBoundary]. Before this component there was
/// no shared row, so there was nowhere to put one, and every scroll repainted
/// the whole list.
///
/// Layout is deliberately fixed: leading, then title over subtitle, then an
/// optional right-hand column of [trailing] over [trailingSubtitle], then
/// [badge]. Everything a screen wants to add goes in [footer], underneath.
///
/// [titleBadge] is the one thing that breaks that left-to-right order, and it
/// earns it: a status mark belongs beside the name it describes, not beyond
/// the money column where the eye has already stopped reading.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleIcon,
    this.titleBadge,
    this.leading,
    this.trailing,
    this.trailingSubtitle,
    this.badge,
    this.footer,
    this.onTap,
    this.onLongPress,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpace.s4,
      vertical: AppSpace.s1,
    ),
  });

  final String title;
  final String? subtitle;

  /// Small icon before [subtitle] — a location pin, a clock.
  final IconData? subtitleIcon;

  /// Drawn immediately after [title], on the same line. A `StatusBadge.mark`,
  /// a lock, a flag — something about the thing the title names.
  ///
  /// Distinct from [badge], which sits at the far right, past the money. Money
  /// forms a straight right-hand column down the list and anything else parked
  /// there bends it.
  final Widget? titleBadge;

  final Widget? leading;

  /// Right-hand headline, usually money. Format through `BrandConfig.money`.
  final String? trailing;

  final String? trailingSubtitle;

  /// A [StatusBadge] or [DeltaPill] at the far right.
  final Widget? badge;

  final Widget? footer;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: margin,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.rM,
            boxShadow: AppShadow.card,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: AppRadius.rM,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s4,
                  vertical: AppSpace.s3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: AppSpace.s3),
                        ],
                        Expanded(child: _titleBlock()),
                        if (trailing != null) ...[
                          const SizedBox(width: AppSpace.s2),
                          _trailingBlock(),
                        ],
                        if (badge != null) ...[
                          const SizedBox(width: AppSpace.s2),
                          badge!,
                        ],
                      ],
                    ),
                    if (footer != null) ...[
                      const SizedBox(height: AppSpace.s2),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleBlock() {
    final titleText = Text(
      title,
      style: AppType.titleS.copyWith(color: AppColors.textPrimary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (titleBadge == null)
          titleText
        else
          Row(
            children: [
              // Flexible, not Expanded: a short name should not push the mark
              // to the far right, and a long one must ellipsize rather than
              // shove the mark off the row.
              Flexible(child: titleText),
              const SizedBox(width: AppSpace.s2),
              titleBadge!,
            ],
          ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              if (subtitleIcon != null) ...[
                Icon(subtitleIcon, size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Text(
                  subtitle!,
                  style: AppType.bodyS.copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _trailingBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          trailing!,
          style: AppType.titleS.copyWith(color: AppColors.textPrimary),
        ),
        if (trailingSubtitle != null)
          Text(
            trailingSubtitle!,
            style: AppType.bodyS.copyWith(color: AppColors.textTertiary),
          ),
      ],
    );
  }
}
