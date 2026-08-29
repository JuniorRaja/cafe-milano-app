import 'package:flutter/material.dart';
import 'dart:async';
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
Future<void> showQuickActionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _QuickActionSheet(),
  );
}

class _QuickActionSheet extends ConsumerWidget {
  const _QuickActionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            _Action(
              icon: Icons.add_shopping_cart_rounded,
              label: 'New order',
              detail: 'Pick a shop and enter quantities',
              onTap: () => _newOrder(context, ref),
            ),
            _Action(
              icon: Icons.payments_outlined,
              label: 'Record payment',
              detail: 'Money received from a shop',
              onTap: () => _recordPayment(context),
            ),
            _Action(
              icon: Icons.storefront_outlined,
              label: 'Add shop',
              detail: 'A new outlet to supply',
              onTap: () {
                Navigator.of(context).pop();
                unawaited(context.push(AppRoutes.shopNew));
              },
            ),
            const SizedBox(height: AppSpace.s3),
          ],
        ),
      ),
    );
  }

  Future<void> _newOrder(BuildContext context, WidgetRef ref) async {
    // The *selected* date, not DateTime.now(). Paging to tomorrow and then
    // creating an order for today is the kind of bug that surfaces in the
    // ledger three weeks later, with no way to tell what happened.
    final date = ref.read(selectedDateProvider);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);

    final shop = await showShopPicker(context, title: 'New order');
    if (shop == null) return;

    navigator.pop();
    unawaited(router.push(AppRoutes.orderEntryFor(shop.id, date: date)));
  }

  Future<void> _recordPayment(BuildContext context) async {
    final navigator = Navigator.of(context);
    final shop = await showShopPicker(context, title: 'Record payment');
    if (shop == null) return;

    navigator.pop();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecordPaymentSheet(shopId: shop.id),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: label,
      subtitle: detail,
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: AppRadius.rS,
        ),
        child: Icon(icon, size: 20, color: AppColors.brandDeep),
      ),
      onTap: onTap,
    );
  }
}
