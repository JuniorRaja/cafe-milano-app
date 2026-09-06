import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// A form field with its label **above** it rather than floating inside it.
///
/// Material's `labelText` starts as placeholder text and animates up when the
/// field is focused or filled, which means a filled form's labels are small,
/// grey and easy to miss — and an empty one shows the label where the value
/// will be. The owner's reference form puts the label above, always the same
/// size, always in the same place, and marks the required ones.
///
/// It defines no colour, size or radius of its own: the input's border, fill
/// and radius all come from `inputDecorationTheme` in `app_theme.dart`, which
/// already carries `AppRadius.rM`. The only thing this adds is the label row.
///
/// Pass the input as [child] and leave `labelText` out of its decoration —
/// two labels is worse than the floating one.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    required this.child,
    this.isRequired = false,
    this.helper,
  });

  final String label;

  /// The input itself — a `TextFormField`, a `DropdownButtonFormField`, or
  /// anything else that draws a value.
  final Widget child;

  /// Adds the required marker. The marker is the app's only use of a bare
  /// asterisk, so it reads as one everywhere.
  final bool isRequired;

  /// A line under the field. For a rule the person needs *before* they type,
  /// not for an error — errors belong to the input's own `errorText`.
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s2, left: AppSpace.s1),
          child: Text.rich(
            TextSpan(
              text: label,
              style: AppType.label.copyWith(color: AppColors.textSecondary),
              children: isRequired
                  ? [
                      TextSpan(
                        text: ' *',
                        style: AppType.label.copyWith(
                          color: AppColors.negative,
                        ),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        child,
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s1, left: AppSpace.s1),
            child: Text(
              helper!,
              style: AppType.caption.copyWith(color: AppColors.textTertiary),
            ),
          ),
      ],
    );
  }
}
