import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../providers/dashboard_provider.dart';

class PulseCard extends ConsumerWidget {
  const PulseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueAsync = ref.watch(todayRevenueProvider);
    final deltaAsync = ref.watch(revenueDeltaProvider);
    final shopsAsync = ref.watch(shopsServedTodayProvider);
    final pendingAsync = ref.watch(pendingConfirmationsProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '❤️',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'The Pulse',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kBrandBrown,
                ),
              ),
              const Spacer(),
              Text(
                'Today',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 2×2 metric grid
          Row(
            children: [
              // Revenue
              Expanded(
                child: _MetricTile(
                  label: "Today's Revenue",
                  child: revenueAsync.when(
                    data: (rev) => Text(
                      '₹${_formatCurrency(rev)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kBrandBrown,
                      ),
                    ),
                    loading: () => _shimmer(),
                    error: (_, _) => const Text('—'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Delta
              Expanded(
                child: _MetricTile(
                  label: 'vs Same Day Last Week',
                  child: deltaAsync.when(
                    data: (delta) => _buildDelta(delta),
                    loading: () => _shimmer(),
                    error: (_, _) => const Text('—'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Shops served
              Expanded(
                child: _MetricTile(
                  label: 'Shops Served',
                  child: shopsAsync.when(
                    data: (data) => Text(
                      '${data.$1} / ${data.$2} shops',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kBrandBrown,
                      ),
                    ),
                    loading: () => _shimmer(),
                    error: (_, _) => const Text('—'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Pending
              Expanded(
                child: _MetricTile(
                  label: 'Pending Confirmations',
                  child: pendingAsync.when(
                    data: (count) => Text(
                      '$count pending',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: count > 0 ? Colors.amber.shade700 : kBrandBrown,
                      ),
                    ),
                    loading: () => _shimmer(),
                    error: (_, _) => const Text('—'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDelta(double? delta) {
    if (delta == null) {
      return Text(
        '→ 0%',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
        ),
      );
    }
    final isUp = delta >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 18,
          color: isUp ? Colors.green.shade600 : Colors.red.shade600,
        ),
        const SizedBox(width: 2),
        Text(
          '${delta.abs().toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isUp ? Colors.green.shade600 : Colors.red.shade600,
          ),
        ),
      ],
    );
  }

  static Widget _shimmer() {
    return Container(
      height: 20,
      width: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  static String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return NumberFormat('#,##,###').format(amount.round());
    }
    return amount.toStringAsFixed(0);
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
