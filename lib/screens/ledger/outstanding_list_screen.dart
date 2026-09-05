import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../providers/date_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../theme/brand_config.dart';
import '../../utils/money.dart';
import '../../widgets/letter_avatar.dart';
import '../../widgets/ui/ui.dart';

/// Who owes what, biggest first. Tapping a row opens that shop's ledger.
///
/// This is where the drawer's outstanding card leads. Doc 10b originally
/// proposed an "Owes mode" on the shop list instead; that was written before
/// doc 07 shipped this screen, and two screens answering the same question is
/// worse than one.
class OutstandingListScreen extends ConsumerWidget {
  const OutstandingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(outstandingByShopProvider);
    final brand = ref.watch(brandProvider);
    final today = ref.watch(todayProvider);

    return AppScaffold(
      caption: 'Money',
      title: 'Outstanding',
      body: shopsAsync.when(
        loading: AppSkeleton.list,
        error: (e, _) => AppErrorView(
          message: 'Could not work out who owes what.',
          cause: '$e',
          onRetry: () => ref.invalidate(outstandingByShopProvider),
        ),
        data: (shops) {
          if (shops.isEmpty) {
            return const EmptyState.inert(
              icon: Icons.check_circle_outline_rounded,
              title: 'Everyone is settled up',
              message: 'No shop is carrying a balance right now.',
            );
          }

          final total = shops.fold<double>(0, (sum, s) => sum + s.outstanding);

          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpace.s6),
            children: [
              HeroStatCard(
                caption: 'Total outstanding',
                value: brand.money(total),
                subtitle: 'Across ${shops.length} '
                    '${shops.length == 1 ? 'shop' : 'shops'}',
              ),
              const SectionHeader(title: 'By shop'),
              for (final shop in shops)
                ListRow(
                  title: shop.shopName,
                  subtitle: shop.area,
                  subtitleIcon:
                      shop.area == null ? null : Icons.place_outlined,
                  leading: LetterAvatar(name: shop.shopName, radius: 18),
                  trailing: brand.money(shop.outstanding),
                  trailingSubtitle: switch (shop.ageInDays(today)) {
                    null => null,
                    final days when days <= 0 => 'today',
                    final days => '$days d old',
                  },
                  onTap: () =>
                      context.push(AppRoutes.shopLedgerFor(shop.shopId)),
                ),
              const _WhatCountsNote(),
            ],
          );
        },
      ),
    );
  }
}

/// The edges of "outstanding", stated where the number is read. Ambiguity here
/// is what makes two screens look like they disagree when they are only
/// counting different things.
class _WhatCountsNote extends StatelessWidget {
  const _WhatCountsNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s4,
        AppSpace.s4,
        AppSpace.s4,
      ),
      child: Text(
        'Includes each shop’s opening balance. Bills dated before a shop’s '
        'opening-balance date are already inside it and are not counted again. '
        'Payments not yet matched to a bill still reduce the figure. Shops in '
        'credit are left out rather than netted off.',
        style: AppType.bodyS.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}
