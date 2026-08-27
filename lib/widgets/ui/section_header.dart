import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// `At Risk Shops` on the left, `View all →` on the right. Replaces the inline
/// `Row` + `Spacer` + `Text` that opens nearly every list in the app, each with
/// its own padding and its own idea of the title size.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.caption,
    this.trailing,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.s4,
      AppSpace.s4,
      AppSpace.s4,
      AppSpace.s2,
    ),
  });

  final String title;

  /// Small uppercase line above the title.
  final String? caption;

  /// Right-hand widget when it is not a text action — a count, a badge.
  /// Ignored when [actionLabel] is set.
  final Widget? trailing;

  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (caption != null)
                  Text(
                    caption!.toUpperCase(),
                    style: AppType.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                Text(
                  title,
                  style: AppType.titleM.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!))
          else
            ?trailing,
        ],
      ),
    );
  }
}
