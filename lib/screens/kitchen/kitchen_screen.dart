import 'dart:math';
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

    return Scaffold(
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
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'By Item'),
            Tab(text: 'By Shop'),
          ],
        ),
      ),
      floatingActionButton: linesAsync.maybeWhen(
        data: (lines) => lines.isNotEmpty
            ? FloatingActionButton(
                onPressed: () => _share(lines, shopMap, productMap),
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                tooltip: 'Share kitchen list',
                child: const Icon(Icons.share),
              )
            : null,
        orElse: () => null,
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
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _share(
    List<KitchenRawLine> lines,
    Map<int, Shop> shopMap,
    Map<int, Product> productMap,
  ) {
    final dateLabel = DateFormat('dd MMM yyyy').format(_date);
    final buf = StringBuffer();
    buf.writeln('🍞 Kitchen List — $dateLabel');
    buf.writeln();

    final Map<int, int> itemTotals = {};
    for (final l in lines) {
      itemTotals[l.productId] = (itemTotals[l.productId] ?? 0) + l.qty;
    }
    final sortedItems = itemTotals.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxItemLen = sortedItems.isEmpty
        ? 0
        : sortedItems
            .map((e) => productMap[e.key]?.name.length ?? 0)
            .fold(0, max);

    buf.writeln('ITEM TOTALS');
    for (final entry in sortedItems) {
      final name = productMap[entry.key]?.name ?? 'Product #${entry.key}';
      buf.writeln(
        '${name.padRight(maxItemLen + 2)}: ${entry.value.toString().padLeft(4)}',
      );
    }

    buf.writeln();

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

    final maxShopLen = shopOrder
        .map((id) => shopMap[id]?.name.length ?? 0)
        .fold(0, max);

    buf.writeln('SHOP-WISE');
    int totalPieces = 0;
    for (final shopId in shopOrder) {
      final shopName = shopMap[shopId]?.name ?? 'Shop #$shopId';
      final productEntries = shopProducts[shopId]!
          .entries
          .where((e) => e.value > 0)
          .toList();
      final shopLine = productEntries
          .map((e) =>
              '${productMap[e.key]?.name ?? '#${e.key}'}×${e.value}')
          .join(', ');
      buf.writeln('${shopName.padRight(maxShopLen + 2)}: $shopLine');
      totalPieces += productEntries.fold<int>(0, (s, e) => s + e.value);
    }

    buf.writeln();
    buf.writeln(
      'Total: ${shopOrder.length} shop${shopOrder.length != 1 ? 's' : ''} | $totalPieces pieces',
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
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
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
    );
  }
}

// ---------------------------------------------------------------------------

class _ByShopView extends StatelessWidget {
  const _ByShopView({
    required this.lines,
    required this.shopMap,
    required this.productMap,
  });

  final List<KitchenRawLine> lines;
  final Map<int, Shop> shopMap;
  final Map<int, Product> productMap;

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

    final List<_ShopViewItem> items = [];
    for (final shopId in shopOrder) {
      final productEntries = shopProducts[shopId]!
          .entries
          .where((e) => e.value > 0)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (productEntries.isEmpty) continue;

      final shop = shopMap[shopId];
      final total = productEntries.fold<int>(0, (s, e) => s + e.value);
      items.add(_ShopViewItem.header(
        shopName: shop?.name ?? 'Shop #$shopId',
        area: shop?.area,
        total: total,
      ));
      for (final pe in productEntries) {
        items.add(_ShopViewItem.product(
          productName: productMap[pe.key]?.name ?? 'Product #${pe.key}',
          qty: pe.value,
        ));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item.isHeader) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (i > 0) const Divider(height: 1),
              Container(
                color: const Color(0xFFFFF8F0),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.shopName!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (item.area != null)
                            Text(
                              item.area!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${item.total} pcs',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: kBrandBrown,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(item.productName!),
              ),
              Text(
                item.qty.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShopViewItem {
  final bool isHeader;
  final String? shopName;
  final String? area;
  final int total;
  final String? productName;
  final int qty;

  const _ShopViewItem.header({
    required this.shopName,
    this.area,
    required this.total,
  })  : isHeader = true,
        productName = null,
        qty = 0;

  const _ShopViewItem.product({
    required this.productName,
    required this.qty,
  })  : isHeader = false,
        shopName = null,
        area = null,
        total = 0;
}
