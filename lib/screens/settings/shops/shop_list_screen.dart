import 'dart:async';

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
/// on the right edge: Ledger, because it is the one you reach for daily, and
/// everything else behind the ⋮.
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
                // Beside the name, not at the far right — the right edge is
                // the actions now, and a state badge parked among buttons
                // reads as one of them.
                titleBadge: shop.isActive
                    ? null
                    : const StatusBadge(
                        label: 'Inactive',
                        tone: AppTone.neutral,
                      ),
                onTap: () => context.push(AppRoutes.shopEditFor(shop.id)),
                badge: _Actions(shop: shop),
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

/// The one thing behind the ⋮. An enum rather than `void`, because
/// `PopupMenuButton` reads a null selection as a dismissal and never calls
/// `onSelected` for it.
enum _ShopAction { toggleActive }

/// Ledger and the ⋮, on the right edge and vertically centred.
///
/// These were a footer row under the shop, which cost every row a line — on a
/// list of thirty shops that is thirty lines of chrome. Ledger is the one a
/// shop gets opened for, so it keeps a target of its own; deactivating happens
/// twice a year and goes behind the menu.
class _Actions extends ConsumerWidget {
  const _Actions({required this.shop});

  final Shop shop;

  /// Deactivating asks first. It takes a shop off the order screen, the
  /// billing screen and the kitchen list at once, and the row that does it
  /// looks exactly like the row that undoes it.
  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    // Read the dao before the dialog: the row can be rebuilt out from under
    // this while the dialog is up.
    final dao = ref.read(databaseProvider).shopDao;

    if (shop.isActive) {
      final confirmed = await confirmDestructive(
        context,
        title: 'Deactivate ${shop.name}?',
        message: 'It stops appearing on the order, billing and kitchen '
            'screens.',
        detail: 'Its past orders, bills and payments are kept, and you can '
            'turn it back on from this list.',
        confirmLabel: 'Deactivate',
      );
      if (!confirmed) return;
    }

    await dao.setShopActive(shop.id, !shop.isActive);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.receipt_long_outlined),
          color: AppColors.textSecondary,
          tooltip: 'Ledger',
          onPressed: () => context.push(AppRoutes.shopLedgerFor(shop.id)),
        ),
        PopupMenuButton<_ShopAction>(
          icon: const Icon(
            Icons.more_vert_rounded,
            color: AppColors.textSecondary,
          ),
          tooltip: 'More actions',
          onSelected: (_) => unawaited(_toggleActive(context, ref)),
          itemBuilder: (_) => [
            PopupMenuItem<_ShopAction>(
              value: _ShopAction.toggleActive,
              child: Text(shop.isActive ? 'Deactivate' : 'Activate'),
            ),
          ],
        ),
      ],
    );
  }
}
