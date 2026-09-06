import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/error_reporting.dart';
import '../ui/ui.dart';

class AttentionFlagsWidget extends ConsumerStatefulWidget {
  const AttentionFlagsWidget({super.key});

  @override
  ConsumerState<AttentionFlagsWidget> createState() =>
      _AttentionFlagsWidgetState();
}

class _AttentionFlagsWidgetState extends ConsumerState<AttentionFlagsWidget> {
  final Set<int> _dismissedIndices = {};
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final flagsAsync = ref.watch(attentionFlagsProvider);

    return RepaintBoundary(
      child: flagsAsync.when(
        data: (flags) {
          if (flags.isEmpty) return const SizedBox.shrink();

          final visible = flags
              .asMap()
              .entries
              .where((e) => !_dismissedIndices.contains(e.key))
              .toList();

          if (visible.isEmpty) return const SizedBox.shrink();

          final displayFlags = _expanded ? visible : visible.take(3).toList();
          final hasMore = !_expanded && visible.length > 3;

          return AppCard(padding: const EdgeInsets.all(16), border: Border.all(color: AppColors.border), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('🚩', style: AppType.body),
                    SizedBox(width: 6),
                    Text(
                      'Attention Flags',
                      style: AppType.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.brandDeep),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...displayFlags.map(
                  (entry) => _FlagCard(
                    flag: entry.value,
                    onDismiss: () {
                      setState(() => _dismissedIndices.add(entry.key));
                    },
                  ),
                ),
                if (hasMore)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = true),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'See all (${visible.length})',
                        style: AppType.label.copyWith(fontWeight: FontWeight.w600, color: AppColors.brandDeep.withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
              ],
            ));
        },
        loading: () => const SizedBox.shrink(),
        // Not `SizedBox.shrink()`. This card is the app's "something needs
        // your attention" surface, so a failure that makes it *disappear* is
        // the worst possible rendering — the screen looks calm precisely when
        // the check that would have raised a flag did not run.
        error: (e, st) {
          reportError(e, st, context: 'attention flags');
          return AppCard(
            margin: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
            border: Border.all(color: AppColors.negative),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.negative,
                  size: 20,
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Text(
                    'Attention checks could not run.',
                    style: AppType.bodyS.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                AppButton.text(
                  label: 'Retry',
                  onPressed: () => ref.invalidate(attentionFlagsProvider),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FlagCard extends StatelessWidget {
  const _FlagCard({required this.flag, required this.onDismiss});
  final AttentionFlag flag;
  final VoidCallback onDismiss;

  Color get _bgColor {
    switch (flag.type) {
      case AttentionFlagType.decliningCategory:
        return AppColors.negativeSoft;
      case AttentionFlagType.inactiveShop:
        return AppColors.warningSoft;
      case AttentionFlagType.newHigh:
        return AppColors.positiveSoft;
      case AttentionFlagType.concentrationRisk:
        return AppColors.warningSoft;
      case AttentionFlagType.zeroDay:
        return AppColors.negativeSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: AppRadius.rS,
        ),
        child: Row(
          children: [
            Text(flag.icon, style: AppType.titleM),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flag.message,
                    style: AppType.label.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (flag.detail != null)
                    Text(
                      flag.detail!,
                      style: AppType.caption.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
