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
  }) : _markOnly = false;

  /// The same meaning as a glyph and nothing else — a green tick for
  /// confirmed, an amber warning for pending.
  ///
  /// The owner asked for "sticker" marks instead of pills on the Orders list.
  /// Eighteen rows every morning, each spending a fifth of its width on a word
  /// whose shape the operator already knows. A filled glyph in the tone colour
  /// reads at a glance and gives the room back to the shop name.
  ///
  /// **The icon font, not a PNG.** Sticker art would be one asset per state
  /// per density, could not take a tone, and would not follow the brand seam;
  /// the app already ships an icon set. If illustrated stickers are ever
  /// wanted, they swap in behind this constructor.
  ///
  /// [label] does not disappear. It becomes the semantic label, because a bare
  /// tick means nothing to a screen reader.
  const StatusBadge.mark({
    super.key,
    required IconData this.icon,
    required this.label,
    this.tone = AppTone.neutral,
  }) : _markOnly = true;

  final String label;
  final AppTone tone;
  final IconData? icon;

  /// Set by [StatusBadge.mark]. Not a parameter: "a badge with no label" and
  /// "a badge whose label is empty" are different things, and only one of them
  /// is legible to a screen reader.
  final bool _markOnly;

  /// Big enough to read across a kitchen at arm's length, small enough to sit
  /// on a row title without pushing it around.
  static const markSize = 20.0;

  @override
  Widget build(BuildContext context) {
    if (_markOnly) {
      // `container: true` is load-bearing. `Icon` wraps its glyph in
      // `ExcludeSemantics`, so there is no child node for a bare annotation to
      // attach to and the label is dropped on the floor — which is how a
      // "keeps the word for a screen reader" claim becomes untrue without
      // anything looking wrong.
      return Semantics(
        container: true,
        label: label,
        child: Icon(icon, size: markSize, color: tone.fg),
      );
    }

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
