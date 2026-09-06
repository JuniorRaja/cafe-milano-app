import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The app's only card. Replaces ~20 sites that each wrote `Card` +
/// `RoundedRectangleBorder` + a hand-picked radius and shadow.
///
/// White ground, `rM` corners, `shadowCard`, `s4` padding. Pass [onTap] to get
/// the ink ripple clipped to the same radius — the thing every hand-rolled
/// card got slightly wrong.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpace.card,
    this.margin = EdgeInsets.zero,
    this.color = AppColors.surface,
    this.borderRadius = AppRadius.rM,
    this.shadow = AppShadow.card,
    this.border,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;
  final BorderRadius borderRadius;
  final List<BoxShadow> shadow;
  final BoxBorder? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);

    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius,
          boxShadow: shadow,
          border: border,
        ),
        child: onTap == null
            ? content
            : Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: borderRadius,
                  child: content,
                ),
              ),
      ),
    );
  }
}
