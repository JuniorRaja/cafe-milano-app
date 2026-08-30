import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/date_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/shop_provider.dart';
import '../../theme/brand_config.dart';
import '../../utils/money.dart';
import '../../widgets/letter_avatar.dart';
import '../../widgets/shell/app_shell.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/shell/shop_picker_sheet.dart';
import '../ledger/record_payment_sheet.dart';

/// Collection, in one place.
///
/// The app could answer "what does this one shop owe me" four taps deep, and
/// could not answer "what am I owed" at all. Doc 10b put the total in the
/// drawer; this makes it a destination, with the two things the owner does
/// next to it — see who owes, and record what came in.
///
/// The window is the last 30 days. Deliberately fixed: a range picker here
/// would duplicate the dashboard's, and the question this screen answers is
/// "where do I stand right now", not "compare two periods".
class FinancesScreen extends ConsumerWidget {
  const FinancesScreen({super.key});

  static const _windowDays = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    final today = ref.watch(todayProvider);
    final summaryAsync = ref.watch(outstandingSummaryProvider);
    final shopsAsync = ref.watch(outstandingByShopProvider);
    final periodAsync = ref.watch(periodMoneyProvider((
      from: today.subtract(const Duration(days: _windowDays)),
      to: today,
    )));

    return AppScaffold(
      caption: 'Money',
      title: 'Finances',
      leading: const ShellDrawerButton(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(outstandingByShopProvider);
          ref.invalidate(outstandingSummaryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpace.s6 * 3),
          children: [
            _Hero(summary: summaryAsync, today: today, brand: brand),
            _Window(period: periodAsync, brand: brand),
            const SizedBox(height: AppSpace.s2),
            _OwedList(shops: shopsAsync, today: today, brand: brand),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _recordPayment(context, ref),
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Record payment'),
      ),
    );
  }

  Future<void> _recordPayment(BuildContext context, WidgetRef ref) async {
    final shop = await showShopPicker(context, title: 'Record payment');
    if (shop == null || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecordPaymentSheet(shopId: shop.id),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.summary, required this.today, required this.brand});

  final AsyncValue<OutstandingSummary> summary;
  final DateTime today;
  final BrandConfig brand;

  @override
  Widget build(BuildContext context) {
    return summary.when(
      loading: () => const Padding(
        padding: AppSpace.page,
        child: AppSkeleton(height: 132, borderRadius: AppRadius.rL),
      ),
      error: (e, _) => AppErrorView(
        message: 'Could not total what you are owed.',
        cause: '$e',
      ),
      data: (data) {
        final age = data.ageInDays(today);
        return HeroStatCard(
          caption: 'Total outstanding',
          value: brand.money(data.total),
          subtitle: data.shopCount == 0
              ? 'Everyone is settled up'
              : 'Owed by ${data.shopCount} '
                  '${data.shopCount == 1 ? 'shop' : 'shops'}'
                  '${age == null ? '' : ' · oldest $age days'}',
        );
      },
    );
  }
}

class _Window extends StatelessWidget {
  const _Window({required this.period, required this.brand});

  final AsyncValue<PeriodMoney> period;
  final BrandConfig brand;

  @override
  Widget build(BuildContext context) {
    final data = period.valueOrNull ?? PeriodMoney.empty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Last 30 days',
          caption: 'Billed against collected',
        ),
        StatBand(
          items: [
            StatBandItem(brand.money(data.billed), label: 'billed'),
            StatBandItem(brand.money(data.collected), label: 'collected'),
            // Net is the number that says whether the month gained ground on
            // old debt or lost it, which neither figure says alone.
            StatBandItem(
              brand.money(data.net.abs()),
              label: data.net >= 0 ? 'caught up' : 'fell behind',
              tone: data.net >= 0 ? AppTone.positive : AppTone.warning,
            ),
          ],
        ),
      ],
    );
  }
}

class _OwedList extends StatelessWidget {
  const _OwedList({required this.shops, required this.today, required this.brand});

  final AsyncValue<List<ShopOutstanding>> shops;
  final DateTime today;
  final BrandConfig brand;

  @override
  Widget build(BuildContext context) {
    return shops.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpace.s4),
        child: AppSkeleton(height: 64, borderRadius: AppRadius.rM),
      ),
      error: (e, _) => AppErrorView(
        message: 'Could not load who owes what.',
        cause: '$e',
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: AppSpace.s6),
            child: EmptyState.inert(
              icon: Icons.check_circle_outline_rounded,
              title: 'Everyone is settled up',
              message: 'No shop is carrying a balance right now.',
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Who owes',
              trailing: Text(
                '${rows.length}',
                style: AppType.label.copyWith(color: AppColors.textSecondary),
              ),
            ),
            for (final shop in rows)
              ListRow(
                title: shop.shopName,
                subtitle: shop.area,
                subtitleIcon: shop.area == null ? null : Icons.place_outlined,
                leading: LetterAvatar(name: shop.shopName, radius: 18),
                trailing: brand.money(shop.outstanding),
                trailingSubtitle: switch (shop.ageInDays(today)) {
                  null => null,
                  final days when days <= 0 => 'today',
                  final days => '$days d old',
                },
                onTap: () => context.push(AppRoutes.shopLedgerFor(shop.shopId)),
              ),
          ],
        );
      },
    );
  }
}
