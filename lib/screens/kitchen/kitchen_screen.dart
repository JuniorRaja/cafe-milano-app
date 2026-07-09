import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/order_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/staggered_fade_in.dart';

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _date;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linesAsync = ref.watch(kitchenLinesForDateProvider(_date));
    final shopMap = ref.watch(allShopsProvider).maybeWhen(
          data: (shops) => {for (final s in shops) s.id: s},
          orElse: () => <int, Shop>{},
        );
    final productMap = ref.watch(allProductsProvider).maybeWhen(
          data: (products) => {for (final p in products) p.id: p},
          orElse: () => <int, Product>{},
        );
    final lines = linesAsync.maybeWhen(
      data: (lines) => lines,
      orElse: () => <KitchenRawLine>[],
    );
    final hasLines = lines.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kitchen Production',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Production plan for the day',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 14),
            label: Text(
              DateFormat('dd MMM yyyy').format(_date),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share kitchen list',
            onPressed: hasLines
                ? () => _tabController.index == 0
                    ? _shareItems(lines, productMap)
                    : _shareAllShops(lines, shopMap, productMap)
                : null,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'By Item'),
            Tab(text: 'By Shop'),
          ],
        ),
      ),
      body: linesAsync.when(
        data: (lines) {
          if (lines.isEmpty) {
            return const _EmptyState();
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _ByItemView(lines: lines, productMap: productMap),
              _ByShopView(
                lines: lines,
                shopMap: shopMap,
                productMap: productMap,
                onShareShop: (shopId) =>
                    _shareShop(shopId, lines, shopMap, productMap),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _shareItems(
    List<KitchenRawLine> lines,
    Map<int, Product> productMap,
  ) {
    final dateLabel = DateFormat('dd MMM yyyy').format(_date);
    final Map<int, int> itemTotals = {};
    for (final l in lines) {
      itemTotals[l.productId] = (itemTotals[l.productId] ?? 0) + l.qty;
    }
    final sorted = itemTotals.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) {
          final na = productMap[a.key]?.name.toLowerCase() ?? '';
          final nb = productMap[b.key]?.name.toLowerCase() ?? '';
          return na.compareTo(nb);
        });

    final buf = StringBuffer();
    buf.writeln('🍞 Kitchen List — $dateLabel');
    buf.writeln();
    for (final entry in sorted) {
      buf.writeln(
          '· ${productMap[entry.key]?.name ?? 'Product #${entry.key}'} × ${entry.value}');
    }
    Share.share(buf.toString().trim());
  }

  void _shareShop(
    int shopId,
    List<KitchenRawLine> lines,
    Map<int, Shop> shopMap,
    Map<int, Product> productMap,
  ) {
    final dateLabel = DateFormat('dd MMM yyyy').format(_date);
    final shop = shopMap[shopId];
    final shopName = shop?.name ?? 'Shop #$shopId';
    final areaLabel = shop?.area != null ? ' — ${shop!.area}' : '';

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
    Share.share(buf.toString().trim());
  }

  void _shareAllShops(
    List<KitchenRawLine> lines,
    Map<int, Shop> shopMap,
    Map<int, Product> productMap,
  ) {
    final dateLabel = DateFormat('dd MMM yyyy').format(_date);
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

    final buf = StringBuffer();
    buf.writeln('🍞 Kitchen List — $dateLabel');
    buf.writeln();
    int totalPieces = 0;
    for (final shopId in shopOrder) {
      final shop = shopMap[shopId];
      final shopName = shop?.name ?? 'Shop #$shopId';
      final areaLabel = shop?.area != null ? ' — ${shop!.area}' : '';
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
    Share.share(buf.toString().trim());
  }
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
  const _ByItemView({required this.lines, required this.productMap});

  final List<KitchenRawLine> lines;
  final Map<int, Product> productMap;

  @override
  Widget build(BuildContext context) {
    final Map<int, int> totals = {};
    for (final l in lines) {
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Card(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Item',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: sorted.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (context, i) {
                  final entry = sorted[i];
                  final product = productMap[entry.key];
                  final unit = product?.unit;
                  return StaggeredFadeIn(
                    index: i,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: kBrandBrown.withAlpha(30),
                        child: const Icon(
                          Icons.bakery_dining,
                          color: kBrandBrown,
                          size: 20,
                        ),
                      ),
                      title: Text(product?.name ?? 'Product #${entry.key}'),
                      subtitle: unit != null ? Text('per $unit') : null,
                      trailing: Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
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
                          if (shop?.area != null)
                            Text(
                              shop!.area!,
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
                      icon: const Icon(Icons.share, size: 18),
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
