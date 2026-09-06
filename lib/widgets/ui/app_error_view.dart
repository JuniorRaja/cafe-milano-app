import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'app_button.dart';

/// What a screen shows when its data failed to load.
///
/// It replaces the sixteen `Text('Error: $e')` sites the lifecycle audit
/// found — a raw exception, in the middle of a blank screen, with no way
/// forward. Those sites are migrated in doc 10c; this release only puts the
/// component on the shelf.
///
/// Three parts, and the split matters:
///
/// * [message] is for the person holding the phone. Plain English, says what
///   did not happen. "Could not load today's orders."
/// * [cause] is the technical detail — the exception. Shown small and muted so
///   it survives into a screenshot without shouting. Pass `null` when there is
///   nothing useful to show; never pass a stack trace.
/// * [onRetry] is the way out. Omit it only when retrying genuinely cannot
///   help, because an error view with no action is the thing this replaces.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.message,
    this.cause,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String message;
  final String? cause;
  final VoidCallback? onRetry;
  final String retryLabel;

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
                color: AppColors.negativeSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppColors.negative,
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.titleM.copyWith(color: AppColors.textPrimary),
            ),
            if (cause != null) ...[
              const SizedBox(height: AppSpace.s2),
              Container(
                padding: const EdgeInsets.all(AppSpace.s3),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppRadius.rS,
                ),
                child: Text(
                  cause!,
                  textAlign: TextAlign.center,
                  style: AppType.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpace.s5),
              AppButton(label: retryLabel, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
