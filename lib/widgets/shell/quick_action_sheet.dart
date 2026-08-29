import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../providers/date_provider.dart';
import '../../screens/ledger/record_payment_sheet.dart';
import '../ui/ui.dart';
import 'shop_picker_sheet.dart';

/// The centre `+`.
///
/// It used to open the Dashboard, which gave the single most prominent control
/// in the app to a shortcut for one screen.
///
/// Worth stating plainly: **this is not the fastest path to a new order.**
/// Home to a shop row is two taps and stays two taps. This is the fastest path
/// from *not being on Home*, and it is the only path to "record a payment"
/// that does not go through four screens.
enum QuickAction {
  newOrder(
    icon: Icons.add_shopping_cart_rounded,
    label: 'New order',
    detail: 'Pick a shop and enter quantities',
  ),
  recordPayment(
    icon: Icons.payments_outlined,
    label: 'Record payment',
    detail: 'Money received from a shop',
  ),
  addShop(
    icon: Icons.storefront_outlined,
    label: 'Add shop',
    detail: 'A new outlet to supply',
  );

  const QuickAction({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;
}

/// The FAB, and everything behind it.
///
/// A widget rather than a `showQuickActionSheet(context)` helper, and the
/// difference is not stylistic. The sheet has to close before its follow-up
/// runs — you cannot show a shop picker over a sheet you are about to pop, and
/// the version that tried used the popped sheet's own context afterwards, by
/// which point it was unmounted and the payment sheet silently never opened.
///
/// So the sheet only *chooses*. This widget, which outlives it, acts.
class QuickActionButton extends ConsumerWidget {
  const QuickActionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      tooltip: 'New order, payment or shop',
      onPressed: () => _run(context, ref),
      child: const Icon(Icons.add_rounded),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<QuickAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _QuickActionSheet(),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case QuickAction.addShop:
        await context.push(AppRoutes.shopNew);

      case QuickAction.newOrder:
        // The *selected* date, not DateTime.now(). Paging to tomorrow and then
        // creating an order for today is the kind of bug that surfaces in the
        // ledger three weeks later, with no way left to tell what happened.
        final date = ref.read(selectedDateProvider);
        final shop = await showShopPicker(context, title: 'New order');
        if (shop == null || !context.mounted) return;
        await context.push(AppRoutes.orderEntryFor(shop.id, date: date));

      case QuickAction.recordPayment:
        final shop = await showShopPicker(context, title: 'Record payment');
        if (shop == null || !context.mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => RecordPaymentSheet(shopId: shop.id),
        );
    }
  }
}

class _QuickActionSheet extends StatelessWidget {
  const _QuickActionSheet();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: AppSpace.s3),
              decoration: const BoxDecoration(
                color: AppColors.border,
                borderRadius: AppRadius.rFull,
              ),
            ),
            for (final action in QuickAction.values)
              ListRow(
                title: action.label,
                subtitle: action.detail,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: AppRadius.rS,
                  ),
                  child: Icon(
                    action.icon,
                    size: 20,
                    color: AppColors.brandDeep,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(action),
              ),
            const SizedBox(height: AppSpace.s3),
          ],
        ),
      ),
    );
  }
}
