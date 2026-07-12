import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../../models/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';

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

    return flagsAsync.when(
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

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('🚩', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text(
                    'Attention Flags',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kBrandBrown,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...displayFlags.map((entry) => _FlagCard(
                    flag: entry.value,
                    onDismiss: () {
                      setState(() => _dismissedIndices.add(entry.key));
                    },
                  )),
              if (hasMore)
                GestureDetector(
                  onTap: () => setState(() => _expanded = true),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'See all (${visible.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kBrandBrown.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
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
        return Colors.red.shade50;
      case AttentionFlagType.inactiveShop:
        return Colors.orange.shade50;
      case AttentionFlagType.newHigh:
        return Colors.green.shade50;
      case AttentionFlagType.concentrationRisk:
        return Colors.amber.shade50;
      case AttentionFlagType.zeroDay:
        return Colors.red.shade50;
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
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(flag.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flag.message,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (flag.detail != null)
                    Text(
                      flag.detail!,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
