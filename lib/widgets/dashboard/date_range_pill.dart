import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../../models/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';

class DateRangePill extends ConsumerWidget {
  const DateRangePill({super.key});

  static const _labels = {
    DashboardPreset.today: 'Today',
    DashboardPreset.thisWeek: 'This Week',
    DashboardPreset.lastWeek: 'Last Week',
    DashboardPreset.thisMonth: 'This Month',
    DashboardPreset.lastMonth: 'Last Month',
    DashboardPreset.last90: 'Last 90 Days',
    DashboardPreset.custom: 'Custom',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRange = ref.watch(dashboardRangeProvider);
    final selected = currentRange.preset;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: DashboardPreset.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final preset = DashboardPreset.values[index];
          final isSelected = preset == selected;

          return GestureDetector(
            onTap: () => _onTap(context, ref, preset),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? kBrandBrown : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? kBrandBrown : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Text(
                  _labels[preset]!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onTap(
      BuildContext context, WidgetRef ref, DashboardPreset preset) async {
    if (preset == DashboardPreset.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: now,
        initialDateRange: DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        ),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: kBrandBrown,
                  ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        ref
            .read(dashboardRangeProvider.notifier)
            .selectCustomRange(picked.start, picked.end);
      }
    } else {
      ref.read(dashboardRangeProvider.notifier).selectPreset(preset);
    }
  }
}
