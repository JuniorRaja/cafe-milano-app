import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The one big figure on a screen, on a dark roast ground: the outstanding
/// total, today's revenue. New — the dashboard previously gave its headline
/// figure the same weight as everything around it.
///
/// [value] is the only thing that should be `displayL` on the screen. Anything
/// competing with it is a [StatBand] item instead.
class HeroStatCard extends StatelessWidget {
  const HeroStatCard({
    super.key,
    required this.caption,
    required this.value,
    this.subtitle,
    this.trailing,
    this.footer,
    this.onTap,
    this.margin = AppSpace.page,
  });

  /// Small uppercase line above the figure. e.g. `TOTAL OUTSTANDING`.
  final String caption;

  /// The already-formatted headline figure. Format money through
  /// `BrandConfig.money`.
  final String value;

  final String? subtitle;

  /// A donut, a sparkline, a [DeltaPill] — anything sitting right of the
  /// figure.
  final Widget? trailing;

  /// Full-width row beneath the figure, above the card edge.
  final Widget? footer;

  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    caption.toUpperCase(),
                    style: AppType.caption.copyWith(
                      color: AppColors.textOnDark.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    value,
                    style: AppType.displayL.copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpace.s1),
                    Text(
                      subtitle!,
                      style: AppType.bodyS.copyWith(
                        color: AppColors.textOnDark.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpace.s3),
              trailing!,
            ],
          ],
        ),
        if (footer != null) ...[const SizedBox(height: AppSpace.s4), footer!],
      ],
    );

    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.brandDeepest,
          borderRadius: AppRadius.rL,
          boxShadow: AppShadow.raised,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.rL,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s5),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
