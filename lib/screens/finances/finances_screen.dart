import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/date_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../theme/brand_config.dart';
import '../../utils/ledger_period.dart';
import '../../utils/money.dart';
import '../../widgets/letter_avatar.dart';
import '../../widgets/shell/app_shell.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/shell/shop_picker_sheet.dart';
import '../ledger/record_payment_sheet.dart';

/// Collection, in one place. Called **Ledger** in the UI.
///
/// The app could answer "what does this one shop owe me" four taps deep, and
/// could not answer "what am I owed" at all. Doc 10b put the total in the
/// drawer; this makes it a destination, with the two things the owner does
/// next to it — see who owes, and record what came in.
///
/// The window used to be a fixed 30 days, on the argument that a range picker
/// here would duplicate the dashboard's. The owner overruled that on the device
/// pass, so there is a period control — its own, not the dashboard's, so the
/// two screens cannot move each other. See [LedgerPeriod].
///
/// **The period does not touch the hero.** What you are owed is a balance as of
/// right now; it does not become a different number because you asked about
/// last month. Only the billed/collected band is filtered.
///
/// The file is still `finances_screen.dart`. Renaming it buys nothing and makes
/// the history harder to follow.
class FinancesScreen extends ConsumerStatefulWidget {
  const FinancesScreen({super.key});

  @override
  ConsumerState<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends ConsumerState<FinancesScreen> {
  LedgerPeriod _period = LedgerPeriod.allTime;
  OwedSort _sort = OwedSort.amount;

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    final today = ref.watch(todayProvider);
    final summaryAsync = ref.watch(outstandingSummaryProvider);
    final shopsAsync = ref.watch(outstandingByShopProvider);
    final periodAsync = ref.watch(periodMoneyProvider(_period.rangeOn(today)));

    return AppScaffold(
      caption: 'Money',
      title: 'Ledger',
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
            _Window(
              period: periodAsync,
              brand: brand,
              selected: _period,
              onSelected: (value) => setState(() => _period = value),
            ),
            const SizedBox(height: AppSpace.s2),
            _OwedList(
              shops: shopsAsync,
              today: today,
              brand: brand,
              sort: _sort,
              onSort: (value) => setState(() => _sort = value),
            ),
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
          // Named for what it is: a balance as of now. The period control
          // below governs the band under it and nothing else, and the word
          // `now` is what stops the two being read as one figure.
          caption: 'Outstanding right now',
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
  const _Window({
    required this.period,
    required this.brand,
    required this.selected,
    required this.onSelected,
  });

  final AsyncValue<PeriodMoney> period;
  final BrandConfig brand;
  final LedgerPeriod selected;
  final ValueChanged<LedgerPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final data = period.valueOrNull ?? PeriodMoney.empty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The caption that used to sit here — `Billed against collected`, in
        // tertiary grey directly on the background art — was unreadable on the
        // phone. The three figures below label themselves, which says it
        // better than a heading over the top of them.
        SectionHeader(
          title: 'Billed and collected',
          trailing: _PeriodMenu(selected: selected, onSelected: onSelected),
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
  const _OwedList({
    required this.shops,
    required this.today,
    required this.brand,
    required this.sort,
    required this.onSort,
  });

  final AsyncValue<List<ShopOutstanding>> shops;
  final DateTime today;
  final BrandConfig brand;
  final OwedSort sort;
  final ValueChanged<OwedSort> onSort;

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

        // Sorted here, not in a query. Eighteen rows, and re-running SQL to
        // reorder them would make the choice a round trip to disk.
        final ordered = [...rows]..sort(switch (sort) {
            OwedSort.amount => (a, b) => b.outstanding.compareTo(a.outstanding),
            OwedSort.name => (a, b) =>
                a.shopName.toLowerCase().compareTo(b.shopName.toLowerCase()),
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Who owes',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${rows.length}',
                    style:
                        AppType.label.copyWith(color: AppColors.textSecondary),
                  ),
                  _SortMenu(selected: sort, onSelected: onSort),
                ],
              ),
            ),
            for (final shop in ordered)
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

/// The period the billed/collected band covers.
///
/// A menu rather than the dashboard's pill row: the pill row is bound to the
/// dashboard's own range, and sharing it would mean changing the period here
/// also changed it there. A menu also fits beside a section title, which a
/// scrolling row of seven pills does not.
class _PeriodMenu extends StatelessWidget {
  const _PeriodMenu({required this.selected, required this.onSelected});

  final LedgerPeriod selected;
  final ValueChanged<LedgerPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return _HeaderMenu<LedgerPeriod>(
      label: selected.label,
      tooltip: 'Change the period',
      values: LedgerPeriod.values,
      labelOf: (value) => value.label,
      selected: selected,
      onSelected: onSelected,
    );
  }
}

/// Amount or name, for the "Who owes" list.
class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.selected, required this.onSelected});

  final OwedSort selected;
  final ValueChanged<OwedSort> onSelected;

  @override
  Widget build(BuildContext context) {
    return _HeaderMenu<OwedSort>(
      label: selected.label,
      tooltip: 'Change the order',
      icon: Icons.swap_vert_rounded,
      values: OwedSort.values,
      labelOf: (value) => value.label,
      selected: selected,
      onSelected: onSelected,
    );
  }
}

/// A small dropdown sized to sit in a [SectionHeader]'s trailing slot.
class _HeaderMenu<T> extends StatelessWidget {
  const _HeaderMenu({
    required this.label,
    required this.tooltip,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
    this.icon = Icons.expand_more_rounded,
  });

  final String label;
  final String tooltip;
  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final value in values)
          CheckedPopupMenuItem<T>(
            value: value,
            checked: value == selected,
            child: Text(labelOf(value)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppType.label.copyWith(color: AppColors.brandDeep),
            ),
            const SizedBox(width: 2),
            Icon(icon, size: 18, color: AppColors.brandDeep),
          ],
        ),
      ),
    );
  }
}
