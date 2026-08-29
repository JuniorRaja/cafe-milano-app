import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// What a button *means*, not what it looks like.
enum AppButtonVariant {
  /// The one action the screen exists for. At most one per screen.
  primary,

  /// A real action that is not the main one.
  secondary,

  /// Low-emphasis, inline.
  text,

  /// Destructive. Delete, discard, remove.
  danger,
}

/// The app's button. Replaces the four separate button themes that used to sit
/// inline in `lib/app.dart`, each with its own radius.
///
/// Everything visual comes from the theme, so changing `BrandConfig.primary`
/// restyles every button with no edit here.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expand = false,
    this.busy = false,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
  }) : variant = AppButtonVariant.text;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  /// Stretch to the full width of the parent.
  final bool expand;

  /// Shows a spinner in place of the icon and disables the button. Every
  /// "saving…" flow in the app used to do this differently or not at all.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final onTap = busy ? null : onPressed;

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: 18),
        if (busy || icon != null) const SizedBox(width: AppSpace.s2),
        Text(label),
      ],
    );

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(onPressed: onTap, child: child),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: onTap,
        child: child,
      ),
      AppButtonVariant.text => TextButton(onPressed: onTap, child: child),
      AppButtonVariant.danger => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.negative,
          foregroundColor: AppColors.textOnDark,
        ),
        child: child,
      ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
