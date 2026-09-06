import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/category_provider.dart';
import '../../providers/date_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/kitchen_list.dart';
import '../../widgets/date_selector.dart';
import '../../widgets/shell/app_shell.dart';
import '../../widgets/ui/ui.dart';

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(selectedDateProvider);
    final linesAsync = ref.watch(kitchenLinesForDateProvider(date));
    final shopMap = ref.watch(allShopsProvider).maybeWhen(
          data: (shops) => {for (final s in shops) s.id: s},
          orElse: () => <int, Shop>{},
        );
    final productMap = ref.watch(allProductsProvider).maybeWhen(
          data: (products) => {for (final p in products) p.id: p},
          orElse: () => <int, Product>{},
        );
    final categories = ref.watch(allCategoriesProvider).maybeWhen(
          data: (c) => c,
          orElse: () => <Category>[],
        );
    final lines = linesAsync.maybeWhen(
      data: (lines) => lines,
      orElse: () => <KitchenRawLine>[],
    );
    final hasLines = lines.isNotEmpty;
    // One grouping, drawn by the By Item tab and written by the share
    // sheet. See lib/services/kitchen_list.dart.
    final itemGroups = groupKitchenLines(
      lines: lines,
      productMap: productMap,
      categories: categories,
    );

    // On `AppScaffold`, like every other shell screen. It had a hand-rolled
    // header, which is why its menu button sat on a different left edge from
    // the other four.
    return AppScaffold(
      caption: 'Kitchen',
      title: 'Production',
      leading: const ShellDrawerButton(),
      actions: [
        IconButton(
          icon: const Icon(Icons.ios_share_rounded),
          color: AppColors.textPrimary,
          tooltip: 'Share kitchen list',
          onPressed: hasLines
              ? () => _tabController.index == 0
                  ? _shareItems(itemGroups, date)
                  : _shareAllShops(lines, shopMap, productMap, date)
              : null,
        ),
      ],
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DateSelector(),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.rS,
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'By Item'),
                Tab(text: 'By Shop'),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s2),
        ],
      ),
      body: linesAsync.when(
        data: (lines) {
          if (lines.isEmpty) {
            return const _EmptyState();
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _ByItemView(groups: itemGroups),
              _ByShopView(
                lines: lines,
                shopMap: shopMap,
                productMap: productMap,
                onShareShop: (shopId) =>
                    _shareShop(shopId, lines, shopMap, productMap, date),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _shareItems(List<KitchenGroup> groups, DateTime date) {
    unawaited(
      Share.share(
        kitchenListText(groups, DateFormat('dd MMM yyyy').format(date)),
      ),
    );
  }

  void _shareShop(
    int shopId,
    List<KitchenRawLine> lines,
    Map<int, Shop> shopMap,
    Map<int, Product> productMap,
    DateTime date,
  ) {
    final dateLabel = DateFormat('dd MMM yyyy').format(date);
    final shop = shopMap[shopId];
    final shopName = shop?.name ?? 'Shop #$shopId';
    final shopArea = shop?.area?.trim();
    final areaLabel = (shopArea != null && shopArea.isNotEmpty) ? ' — $shopArea' : '';

    final Map<int, int> totals = {};
    for (final l in lines.where((l) => l.shopId == shopId)) {
      totals[l.productId] = (totals[l.productId] ?? 0) + l.qty;
    }
    final sorted = totals.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) {
          final na = productMap[a.key]?.name.toLowerCase() ?? '';
          final nb = productMap[b.key]?.name.toLowerCase() ?? '';
          return na.compareTo(nb);
        });

    final buf = StringBuffer();
    buf.writeln('🏪 $shopName$areaLabel — $dateLabel');
    buf.writeln();
    for (final entry in sorted) {
      buf.writeln(
          '· ${productMap[entry.key]?.name ?? '#${entry.key}'} × ${entry.value}');
    }
    unawaited(Share.share(buf.toString().trim()));
  }

  void _shareAllShops(
    List<KitchenRawLine> lines,
    Map<int, Shop> shopMap,
    Map<int, Product> productMap,
    DateTime date,
  ) {
    final dateLabel = DateFormat('dd MMM yyyy').format(date);
    final Map<int, Map<int, int>> shopProducts = {};
    final List<int> shopOrder = [];
    for (final l in lines) {
      if (!shopProducts.containsKey(l.shopId)) {
        shopOrder.add(l.shopId);
        shopProducts[l.shopId] = {};
      }
      shopProducts[l.shopId]![l.productId] =
          (shopProducts[l.shopId]![l.productId] ?? 0) + l.qty;
    }
    _sortShops(shopOrder, shopMap);

    final buf = StringBuffer();
    buf.writeln('🍞 Kitchen List — $dateLabel');
    buf.writeln();
    int totalPieces = 0;
    for (final shopId in shopOrder) {
      final shop = shopMap[shopId];
      final shopName = shop?.name ?? 'Shop #$shopId';
      final shopArea = shop?.area?.trim();
      final areaLabel = (shopArea != null && shopArea.isNotEmpty) ? ' — $shopArea' : '';
      buf.writeln('🏪 $shopName$areaLabel');
      final productEntries = shopProducts[shopId]!
          .entries
          .where((e) => e.value > 0)
          .toList()
        ..sort((a, b) {
            final na = productMap[a.key]?.name.toLowerCase() ?? '';
            final nb = productMap[b.key]?.name.toLowerCase() ?? '';
            return na.compareTo(nb);
          });
      for (final pe in productEntries) {
        buf.writeln(
            '· ${productMap[pe.key]?.name ?? '#${pe.key}'} × ${pe.value}');
      }
      totalPieces += productEntries.fold<int>(0, (s, e) => s + e.value);
      buf.writeln();
    }
    buf.writeln(
      'Total: ${shopOrder.length} shop${shopOrder.length != 1 ? 's' : ''} · $totalPieces pieces',
    );
    unawaited(Share.share(buf.toString().trim()));
  }

  void _sortShops(List<int> shopOrder, Map<int, Shop> shopMap) {
    shopOrder.sort((a, b) => _cmpShops(shopMap[a], shopMap[b]));
  }

  static int _cmpShops(Shop? sa, Shop? sb) =>
      (sa?.name ?? '').toLowerCase().compareTo((sb?.name ?? '').toLowerCase());
}

// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No orders for this date',
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ByItemView extends StatelessWidget {
  const _ByItemView({required this.groups});

  final List<KitchenGroup> groups;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // The nav bar floats over the body now. See `AppShell.bottomInset`.
      padding: EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s4,
        AppShell.bottomInset(context),
      ),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final group = groups[i];
        return RepaintBoundary(
          child: AppCard(
            margin: const EdgeInsets.only(bottom: AppSpace.s2),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpace.s3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${group.emoji} ${group.name}',
                          style: AppType.titleS,
                        ),
                      ),
                      Text(
                        '${group.total} pcs',
                        style: AppType.label
                            .copyWith(color: AppColors.brandDeep),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  indent: AppSpace.s3,
                  endIndent: AppSpace.s3,
                ),
                ...group.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s3,
                      vertical: AppSpace.s2,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(item.name, style: AppType.body),
                        ),
                        Text('${item.qty}', style: AppType.titleL),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s2),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _ByShopView extends StatelessWidget {
  const _ByShopView({
    required this.lines,
    required this.shopMap,
    required this.productMap,
    required this.onShareShop,
  });

  final List<KitchenRawLine> lines;
  final Map<int, Shop> shopMap;
  final Map<int, Product> productMap;
  final void Function(int shopId) onShareShop;

  @override
  Widget build(BuildContext context) {
    final Map<int, Map<int, int>> shopProducts = {};
    final List<int> shopOrder = [];
    for (final l in lines) {
      if (!shopProducts.containsKey(l.shopId)) {
        shopOrder.add(l.shopId);
        shopProducts[l.shopId] = {};
      }
      shopProducts[l.shopId]![l.productId] =
          (shopProducts[l.shopId]![l.productId] ?? 0) + l.qty;
    }
    shopOrder.sort((a, b) => _KitchenScreenState._cmpShops(shopMap[a], shopMap[b]));

    return ListView.builder(
      // The nav bar floats over the body now. See `AppShell.bottomInset`.
      padding: EdgeInsets.fromLTRB(16, 8, 16, AppShell.bottomInset(context)),
      itemCount: shopOrder.length,
      itemBuilder: (context, i) {
        final shopId = shopOrder[i];
        final shop = shopMap[shopId];
        final productEntries = shopProducts[shopId]!
            .entries
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) {
              final na = productMap[a.key]?.name.toLowerCase() ?? '';
              final nb = productMap[b.key]?.name.toLowerCase() ?? '';
              return na.compareTo(nb);
            });
        if (productEntries.isEmpty) return const SizedBox.shrink();

        final total = productEntries.fold<int>(0, (s, e) => s + e.value);

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop?.name ?? 'Shop #$shopId',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (shop?.area?.trim().isNotEmpty == true)
                            Text(
                              shop!.area!.trim(),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '$total pcs',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: kBrandBrown),
                    ),
                    IconButton(
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      onPressed: () => onShareShop(shopId),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Share ${shop?.name ?? 'shop'}',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ...productEntries.map(
                (pe) => Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(productMap[pe.key]?.name ??
                            'Product #${pe.key}'),
                      ),
                      Text(
                        pe.value.toString(),
                        style:
                            const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}
