import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'app_button.dart';

/// The app's one "are you sure?".
///
/// There were seven of these, hand-written, drifting apart: three said
/// "Delete", one said "Erase & Restore", one used a `FilledButton` for the
/// destructive action and the rest a `TextButton`, and none of them coloured
/// the destructive choice. A confirm dialog is the last thing a user reads
/// before losing data — it is exactly the wrong place for each screen to have
/// its own idea.
///
/// Returns true only if the user confirmed. A dismissed dialog is a "no",
/// never a null the caller has to remember to handle.
///
/// ```dart
/// if (!await confirmDestructive(
///   context,
///   title: 'Delete Shop',
///   message: 'Delete this shop permanently?',
/// )) return;
/// ```
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,

  /// The destructive button's label. Say what will happen — "Delete",
  /// "Erase & Restore" — never "OK", which tells the user nothing about what
  /// they are agreeing to.
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',

  /// Extra context under the message: what else this will affect. Shown muted,
  /// so the primary sentence stays the one that is read.
  String? detail,

  /// Whether the confirm button is drawn as destructive. True for anything
  /// that loses data. False for a plain "are you sure?" — confirming an empty
  /// order is a question, not a warning, and colouring it red teaches the user
  /// to ignore red.
  bool destructive = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rM),
      title: Text(title, style: AppType.titleM),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: AppType.body.copyWith(color: AppColors.textSecondary),
          ),
          if (detail != null) ...[
            const SizedBox(height: AppSpace.s3),
            Text(
              detail,
              style: AppType.bodyS.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpace.s3,
        0,
        AppSpace.s3,
        AppSpace.s3,
      ),
      actions: [
        AppButton.text(label: cancelLabel, onPressed: () => Navigator.pop(ctx, false)),
        if (destructive)
          AppButton.danger(
            label: confirmLabel,
            onPressed: () => Navigator.pop(ctx, true),
          )
        else
          AppButton(
            label: confirmLabel,
            onPressed: () => Navigator.pop(ctx, true),
          ),
      ],
    ),
  );
  return confirmed ?? false;
}
