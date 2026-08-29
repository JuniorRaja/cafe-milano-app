import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// A small pill stating what something *is*: Pending, Confirmed, Overdue,
/// Partial. Replaces three separate private `_StatusChip` classes.
///
/// The tone is semantic and never decorative — a red badge means something is
/// wrong with that row, so do not reach for [AppTone.negative] because it looks
/// good next to the gold.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = AppTone.neutral,
    this.icon,
  });

  final String label;
  final AppTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s2,
        vertical: AppSpace.s1,
      ),
      decoration: BoxDecoration(
        color: tone.soft,
        borderRadius: AppRadius.rFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tone.fg),
            const SizedBox(width: AppSpace.s1),
          ],
          Text(label, style: AppType.label.copyWith(color: tone.fg)),
        ],
      ),
    );
  }
}
