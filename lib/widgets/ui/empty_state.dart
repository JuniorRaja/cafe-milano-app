import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'app_button.dart';

/// Replaces the six inert empty states in the app — a grey icon and one line
/// of grey text, telling the user they have nothing without telling them what
/// to do about it.
///
/// [actionLabel] and [onAction] are **required**. An empty shop list offers
/// "Add your first shop", not sympathy. If a state genuinely has no action —
/// "no orders on a past date" — use [EmptyState.inert] and say so at the call
/// site, because it is the exception.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required String this.actionLabel,
    required VoidCallback this.onAction,
  });

  /// For the rare state with nothing to offer: a past date with no orders, a
  /// filter that matched nothing. Prefer the default constructor.
  const EmptyState.inert({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  }) : actionLabel = null,
       onAction = null;

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.s4),
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.textTertiary),
            ),
            const SizedBox(height: AppSpace.s4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppType.titleM.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpace.s2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.bodyS.copyWith(color: AppColors.textSecondary),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpace.s5),
              AppButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
