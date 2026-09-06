import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../providers/shop_provider.dart';
import '../letter_avatar.dart';
import '../ui/ui.dart';

/// One reusable "which shop?" sheet: a search field, a recents row, then the
/// full list.
///
/// Both quick actions need it, and doc 07's statement flow will too. Written
/// once here rather than three times badly.
///
/// Returns the chosen [Shop], or null if dismissed.
Future<Shop?> showShopPicker(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<Shop>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShopPickerSheet(title: title),
  );
}

/// Shops the owner picked most recently, newest first.
///
/// In-memory and process-lifetime on purpose. It is a convenience, not a
/// setting: persisting it would mean a schema or preferences decision for
/// something whose whole value is "the three shops I have touched today".
final _recentShopIdsProvider =
    NotifierProvider<RecentShopIds, List<int>>(RecentShopIds.new);

class RecentShopIds extends Notifier<List<int>> {
  static const _max = 3;

  @override
  List<int> build() => const [];

  void record(int shopId) {
    state = [shopId, ...state.where((id) => id != shopId)].take(_max).toList();
  }
}

class _ShopPickerSheet extends ConsumerStatefulWidget {
  const _ShopPickerSheet({required this.title});

  final String title;

  @override
  ConsumerState<_ShopPickerSheet> createState() => _ShopPickerSheetState();
}

class _ShopPickerSheetState extends ConsumerState<_ShopPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(Shop shop) {
    ref.read(_recentShopIdsProvider.notifier).record(shop.id);
    Navigator.of(context).pop(shop);
  }

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(activeShopsProvider);
    final recentIds = ref.watch(_recentShopIdsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const _SheetGrip(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                0,
                AppSpace.s4,
                AppSpace.s3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: AppType.titleL.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s3),
                  TextField(
                    controller: _controller,
                    autofocus: false,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search shops',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: shopsAsync.when(
                loading: AppSkeleton.list,
                error: (e, _) => AppErrorView(
                  message: 'Could not load your shops.',
                  cause: '$e',
                  onRetry: () => ref.invalidate(activeShopsProvider),
                ),
                data: (shops) => _list(shops, recentIds, scrollController),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(
    List<Shop> shops,
    List<int> recentIds,
    ScrollController scrollController,
  ) {
    final q = _query.trim().toLowerCase();
    final matches = shops.where((s) {
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          (s.area?.toLowerCase().contains(q) ?? false);
    }).toList();

    if (matches.isEmpty) {
      return EmptyState.inert(
        icon: Icons.search_off_rounded,
        title: q.isEmpty ? 'No active shops' : 'No shop matches',
        message: q.isEmpty
            ? 'Add a shop before recording orders or payments.'
            : 'Nothing here matches "$_query".',
      );
    }

    // Recents are hidden while searching: the point of typing is that you know
    // which shop you want.
    final recents = q.isNotEmpty
        ? const <Shop>[]
        : [
            for (final id in recentIds)
              ...matches.where((s) => s.id == id).take(1),
          ];

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: AppSpace.s6),
      children: [
        if (recents.isNotEmpty) ...[
          const SectionHeader(title: 'Recent'),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: AppSpace.page,
              itemCount: recents.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s2),
              itemBuilder: (context, i) => ActionChip(
                label: Text(recents[i].name),
                onPressed: () => _pick(recents[i]),
              ),
            ),
          ),
        ],
        SectionHeader(
          title: 'All shops',
          trailing: Text(
            '${matches.length}',
            style: AppType.label.copyWith(color: AppColors.textSecondary),
          ),
        ),
        for (final shop in matches)
          ListRow(
            title: shop.name,
            subtitle: shop.area,
            subtitleIcon: shop.area == null ? null : Icons.place_outlined,
            leading: LetterAvatar(name: shop.name, radius: 18),
            onTap: () => _pick(shop),
          ),
      ],
    );
  }
}

class _SheetGrip extends StatelessWidget {
  const _SheetGrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: AppSpace.s3),
      decoration: const BoxDecoration(
        color: AppColors.border,
        borderRadius: AppRadius.rFull,
      ),
    );
  }
}
