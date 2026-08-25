import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/ledger_provider.dart';

/// Who owes what, biggest first. Tapping a row opens that shop's ledger.
class OutstandingListScreen extends ConsumerWidget {
  const OutstandingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(outstandingByShopProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outstanding',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: shopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shops) {
          if (shops.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 56, color: Colors.green.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Nothing outstanding — every shop is settled up.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ],
                ),
              ),
            );
          }

          final total = shops.fold<double>(0, (sum, s) => sum + s.outstanding);

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 20, color: Colors.red.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '₹${NumberFormat('#,##0').format(total)} across '
                        '${shops.length} ${shops.length == 1 ? 'shop' : 'shops'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: shops.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final shop = shops[index];
                    return ListTile(
                      title: Text(
                        shop.shopName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: shop.area == null
                          ? null
                          : Text(shop.area!,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${NumberFormat('#,##0').format(shop.outstanding)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              size: 20, color: Colors.grey),
                        ],
                      ),
                      // Not the shell's /profile/shops/:id/ledger — see the
                      // route table: this screen lives outside the shell.
                      onTap: () =>
                          context.push('/outstanding/${shop.shopId}/ledger'),
                    );
                  },
                ),
              ),
              // The edges of "outstanding" stated where the number is read —
              // ambiguity here is what makes two screens look like they
              // disagree when they are only counting different things.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Text(
                  'Includes each shop’s opening balance. Bills dated before a '
                  'shop’s opening-balance date are already inside it and are not '
                  'counted again. Payments not yet matched to a bill still reduce '
                  'the figure. Shops in credit are left out rather than netted off.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
