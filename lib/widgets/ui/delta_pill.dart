import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// A signed change: `↑8%`, `+₹240`, `−₹120`. New — the app previously drew
/// every delta in brand gold or brown, which is why nothing on screen read as
/// good or bad.
///
/// The tone is derived from the sign, not chosen at the call site. Pass
/// [inverted] for figures where up is bad (outstanding, wastage).
class DeltaPill extends StatelessWidget {
  const DeltaPill({
    super.key,
    required this.value,
    required this.label,
    this.inverted = false,
    this.dense = false,
  });

  /// Only its sign is read. The text shown is [label].
  final num value;

  /// The already-formatted figure, e.g. `8%` or `₹240`. Format money through
  /// `BrandConfig.money`.
  final String label;

  /// Set for metrics where an increase is bad.
  final bool inverted;

  final bool dense;

  AppTone get _tone {
    if (value == 0) return AppTone.neutral;
    final good = inverted ? value < 0 : value > 0;
    return good ? AppTone.positive : AppTone.negative;
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    final arrow = value == 0
        ? Icons.remove_rounded
        : value > 0
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpace.s1 : AppSpace.s2,
        vertical: dense ? 1 : AppSpace.s1,
      ),
      decoration: BoxDecoration(
        color: tone.soft,
        borderRadius: AppRadius.rFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(arrow, size: 12, color: tone.fg),
          const SizedBox(width: 2),
          Text(label, style: AppType.label.copyWith(color: tone.fg)),
        ],
      ),
    );
  }
}
