import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// A soft-filled banner carrying an explanation: `Reason: shop closed Monday`.
/// New — the app had nowhere to say *why*, so it never did.
///
/// Defaults to [AppTone.info], the tone reserved for reasons, hints and
/// explanations. Use [AppTone.warning] only when the note is about something
/// incomplete, and [AppTone.negative] only when something is wrong.
class NoteBanner extends StatelessWidget {
  const NoteBanner({
    super.key,
    required this.text,
    this.label,
    this.tone = AppTone.info,
    this.icon = Icons.info_outline_rounded,
    this.margin = EdgeInsets.zero,
    this.onTap,
  });

  final String text;

  /// Bold lead-in before the text, e.g. `Reason:`.
  final String? label;

  final AppTone tone;
  final IconData icon;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.rS,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.s3),
            decoration: BoxDecoration(
              color: tone.soft,
              borderRadius: AppRadius.rS,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: tone.fg),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (label != null)
                          TextSpan(
                            text: '$label ',
                            style: AppType.label.copyWith(color: tone.fg),
                          ),
                        TextSpan(
                          text: text,
                          style: AppType.bodyS.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
