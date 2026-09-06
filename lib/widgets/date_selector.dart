import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../app.dart';
import '../providers/date_provider.dart';
import '../utils/relative_day.dart';

class DateSelector extends ConsumerWidget {
  const DateSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final label = DateFormat('dd MMM yyyy, EEE').format(date);
    // Read through todayProvider, so the word re-derives at midnight along
    // with everything else rather than saying "Today" about yesterday.
    final relative = relativeDayLabel(date, today: ref.watch(todayProvider));

    return Card(
      color: kSurface,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ArrowBtn(
              icon: Icons.chevron_left,
              onPressed: () => ref.read(selectedDateProvider.notifier).state =
                  date.subtract(const Duration(days: 1)),
            ),
            Expanded(
              child: Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  // The date stays the headline. A bill dated "Next Tue" is a
                  // bill whose real date the owner still has to read out.
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      if (relative != null)
                        Text(
                          relative,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 11),
                        ),
                    ],
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
              ),
            ),
            _ArrowBtn(
              icon: Icons.chevron_right,
              onPressed: () => ref.read(selectedDateProvider.notifier).state =
                  date.add(const Duration(days: 1)),
            ),
          ],
        ),
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
        color: kBrandGold.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Icon(icon, size: 20, color: kBrandBrown),
      ),
    );
  }
}
