import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../database/app_database.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../widgets/letter_avatar.dart';
import '../../../widgets/ui/ui.dart';

/// The shops master.
///
/// Was a bare `ListView` of `ListTile`s, each carrying a tappable Active chip,
/// a ledger button and an edit button crammed into `trailing` — three targets
/// in the space of one, with the row itself doing nothing. Now the row opens
/// the shop, its state is a badge rather than a control, and the actions live
/// in one menu.
class ShopListScreen extends ConsumerWidget {
  const ShopListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(allShopsProvider);

    return MasterListPage(
      caption: 'Catalogue',
      title: 'Shops',
      searchHint: 'Search shops by name or area',
      stats: shopsAsync.whenOrNull(
        data: (shops) {
          final active = shops.where((s) => s.isActive).length;
          return [
            StatBandItem('${shops.length}', label: 'shops'),
            StatBandItem('$active', label: 'active'),
            if (shops.length - active > 0)
              StatBandItem(
                '${shops.length - active}',
                label: 'inactive',
                tone: AppTone.warning,
              ),
          ];
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.shopNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add shop'),
      ),
      builder: (context, query) => shopsAsync.when(
        loading: AppSkeleton.list,
        error: (e, _) => AppErrorView(
          message: 'Could not load your shops.',
          cause: '$e',
          onRetry: () => ref.invalidate(allShopsProvider),
        ),
        data: (shops) {
          // Active first, then inactive — an inactive shop is history, not
          // something to scroll past on the way to today's work.
          final ordered = [
            ...shops.where((s) => s.isActive),
            ...shops.where((s) => !s.isActive),
          ];
          final matches = ordered.where((s) => _matches(s, query)).toList();

          if (matches.isEmpty) {
            return query.isEmpty
                ? EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'No shops yet',
                    message: 'Add the outlets you supply and their orders can '
                        'start here.',
                    actionLabel: 'Add your first shop',
                    onAction: () => context.push(AppRoutes.shopNew),
                  )
                : const EmptyState.inert(
                    icon: Icons.search_off_rounded,
                    title: 'No shop matches',
                    message: 'Try part of the name, or the area.',
                  );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: AppSpace.s2, bottom: 96),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final shop = matches[index];
              return ListRow(
                title: shop.name,
                subtitle: shop.area,
                subtitleIcon: shop.area == null ? null : Icons.place_outlined,
                leading: LetterAvatar(name: shop.name, radius: 20),
                badge: shop.isActive
                    ? null
                    : const StatusBadge(
                        label: 'Inactive',
                        tone: AppTone.neutral,
                      ),
                onTap: () => context.push(AppRoutes.shopEditFor(shop.id)),
                trailing: null,
                footer: _Actions(shop: shop),
              );
            },
          );
        },
      ),
    );
  }

  bool _matches(Shop shop, String query) {
    if (query.isEmpty) return true;
    return shop.name.toLowerCase().contains(query) ||
        (shop.area?.toLowerCase().contains(query) ?? false);
  }
}

/// Ledger and the active toggle, under the row rather than jammed beside the
/// name. Two labelled targets instead of three unlabelled icons.
class _Actions extends ConsumerWidget {
  const _Actions({required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s2),
      child: Row(
        children: [
          AppButton.text(
            label: 'Ledger',
            icon: Icons.receipt_long_outlined,
            onPressed: () => context.push(AppRoutes.shopLedgerFor(shop.id)),
          ),
          const Spacer(),
          AppButton.text(
            label: shop.isActive ? 'Deactivate' : 'Activate',
            onPressed: () => ref
                .read(databaseProvider)
                .shopDao
                .setShopActive(shop.id, !shop.isActive),
          ),
        ],
      ),
    );
  }
}
