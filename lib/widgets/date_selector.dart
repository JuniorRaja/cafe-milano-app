import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/date_provider.dart';

class DateSelector extends ConsumerWidget {
  const DateSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final label = DateFormat('dd MMM yyyy, EEE').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ArrowBtn(
            icon: Icons.chevron_left,
            onPressed: () => ref.read(selectedDateProvider.notifier).state =
                date.subtract(const Duration(days: 1)),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null && context.mounted) {
                ref.read(selectedDateProvider.notifier).state = picked;
              }
            },
          ),
          const SizedBox(width: 8),
          _ArrowBtn(
            icon: Icons.chevron_right,
            onPressed: () => ref.read(selectedDateProvider.notifier).state =
                date.add(const Duration(days: 1)),
          ),
        ],
      ),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  const _ArrowBtn({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Icon(icon, size: 20, color: Colors.grey.shade700),
      ),
    );
  }
}
