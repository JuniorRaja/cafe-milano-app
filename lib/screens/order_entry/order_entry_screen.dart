import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../widgets/product_qty_row.dart';

class OrderEntryScreen extends ConsumerStatefulWidget {
  const OrderEntryScreen({super.key, required this.shopId, this.date});

  final int shopId;
  final String? date; // YYYY-MM-DD

  @override
  ConsumerState<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends ConsumerState<OrderEntryScreen> {
  late DateTime _date;

  int? _orderId;
  bool _isConfirmed = false;

  List<Product> _products = [];
  Map<int, double> _priceMap = {};
  Map<int, int> _qtys = {};
  Map<int, double> _snapshotPrices = {};

  Shop? _shop;
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.date != null) {
      final p = widget.date!.split('-');
      _date = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } else {
      final now = DateTime.now();
      _date = DateTime(now.year, now.month, now.day);
    }
    _init();
  }

  Future<void> _init() async {
    final db = ref.read(databaseProvider);

    final shop = await db.shopDao.getShop(widget.shopId);
    final order = await db.orderDao.getOrCreateOrder(widget.shopId, _date);

    final results = await Future.wait([
      db.productDao.watchActiveProducts().first,
      db.priceDao.watchPricesForShop(widget.shopId).first,
      db.priceDao.watchStandingOrdersForShop(widget.shopId).first,
      db.orderDao.watchOrderWithLines(order.id).first,
    ]);

    if (!mounted) return;

    final prods = results[0] as List<Product>;
    final prices = results[1] as List<ShopPrice>;
    final sos = results[2] as List<StandingOrder>;
    final owl = results[3] as OrderWithLines?;

    final priceMap = <int, double>{
      for (final p in prices) p.productId: p.price
    };
    final soMap = <int, int>{for (final s in sos) s.productId: s.defaultQty};

    final Map<int, int> qtys;
    final Map<int, double> snapshotPrices;

    if (owl != null && owl.lines.isNotEmpty) {
      qtys = {for (final l in owl.lines) l.productId: l.qty};
      snapshotPrices = {for (final l in owl.lines) l.productId: l.unitPrice};
      for (final p in prods) {
        qtys.putIfAbsent(p.id, () => 0);
      }
    } else {
      qtys = {for (final p in prods) p.id: soMap[p.id] ?? 0};
      snapshotPrices = {};
    }

    setState(() {
      _shop = shop;
      _orderId = order.id;
      _isConfirmed = order.isConfirmed;
      _products = prods;
      _priceMap = priceMap;
      _qtys = qtys;
      _snapshotPrices = snapshotPrices;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _setQty(int productId, int qty) {
    setState(() {
      _qtys[productId] = qty;
      if (_isConfirmed) {
        _isConfirmed = false;
        ref.read(databaseProvider).orderDao.setConfirmed(_orderId!, false);
      }
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    if (_orderId == null) return;
    final lines = _products
        .map((p) => OrderLinesCompanion(
              productId: Value(p.id),
              qty: Value(_qtys[p.id] ?? 0),
              unitPrice:
                  Value(_priceMap[p.id] ?? _snapshotPrices[p.id] ?? 0.0),
            ))
        .toList();
    await ref
        .read(databaseProvider)
        .orderDao
        .replaceOrderLines(_orderId!, lines);
  }

  Future<void> _confirmOrder() async {
    _debounce?.cancel();
    final totalQty = _qtys.values.fold(0, (a, b) => a + b);
    if (totalQty == 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('All quantities are 0'),
          content: const Text('Confirm this order with no items?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    await _save();
    if (!mounted) return;
    await ref.read(databaseProvider).orderDao.setConfirmed(_orderId!, true);
    if (!mounted) return;
    setState(() => _isConfirmed = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Order confirmed.'),
          duration: Duration(seconds: 2)),
    );
  }

  Future<void> _loadStandingOrder() async {
    final hasEntries = _qtys.values.any((q) => q > 0);
    if (hasEntries) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Load Standing Order'),
          content: const Text(
            'Replace current entries with standing order quantities? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final db = ref.read(databaseProvider);
    final sos =
        await db.priceDao.watchStandingOrdersForShop(widget.shopId).first;
    if (!mounted) return;
    final soMap = {for (final s in sos) s.productId: s.defaultQty};
    setState(() {
      for (final p in _products) {
        _qtys[p.id] = soMap[p.id] ?? 0;
      }
      if (_isConfirmed) {
        _isConfirmed = false;
        db.orderDao.setConfirmed(_orderId!, false);
      }
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          title: const Text('Order Entry'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final dateLabel = DateFormat('dd MMM yyyy, EEE').format(_date);
    final unpricedCount =
        _products.where((p) => !_priceMap.containsKey(p.id)).length;
    final pricedCount = _products.length - unpricedCount;

    int totalItems = 0;
    double totalAmount = 0;
    for (final p in _products) {
      final qty = _qtys[p.id] ?? 0;
      final price = _priceMap[p.id];
      if (qty > 0 && price != null) {
        totalItems += qty;
        totalAmount += qty * price;
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: kBrandBrown,
              child: Icon(Icons.storefront, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _shop?.name ?? 'Shop',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_shop?.area != null)
                    Text(
                      _shop!.area!,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.normal),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _loadStandingOrder,
            child: const Text(
              'Load Standing Order',
              style: TextStyle(color: kBrandBrown, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Two-column info card — icon on left spanning both rows
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Card(
              color: Colors.white,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 22,
                                color: Colors.grey.shade400),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Order Date',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                                Text(
                                  dateLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Row(
                            children: [
                              Icon(Icons.receipt_outlined,
                                  size: 22,
                                  color: Colors.grey.shade400),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Order Type',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500),
                                  ),
                                  const Text(
                                    'Regular Order',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Warning banner
          if (unpricedCount > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Prices not set for $unpricedCount product${unpricedCount > 1 ? 's' : ''} — billing will show ₹0',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.deepOrange),
                    ),
                  ),
                ],
              ),
            ),
          // Products section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Text(
                  'Products',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '$pricedCount items',
                  style: const TextStyle(color: kBrandBrown, fontSize: 13),
                ),
              ],
            ),
          ),
          // Product list
          Expanded(
            child: _products.isEmpty
                ? const Center(
                    child: Text('No active products',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    itemCount: _products.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (context, i) {
                      final product = _products[i];
                      final price = _priceMap[product.id];
                      final qty = _qtys[product.id] ?? 0;
                      return ProductQtyRow(
                        product: product,
                        price: price,
                        qty: qty,
                        onDecrement: price != null
                            ? () => _setQty(
                                product.id, (qty - 1).clamp(0, 9999))
                            : null,
                        onIncrement: price != null
                            ? () => _setQty(product.id, qty + 1)
                            : null,
                      );
                    },
                  ),
          ),
          // Bottom bar
          SafeArea(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 8,
                    color: Colors.black.withAlpha(20),
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${NumberFormat('#,##0.##').format(totalAmount)}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Order Total · $totalItems items',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isConfirmed ? null : _confirmOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBrandGold,
                      foregroundColor: Colors.black87,
                      disabledBackgroundColor: Colors.green.shade50,
                      disabledForegroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child:
                        Text(_isConfirmed ? 'Confirmed ✓' : 'Confirm Order →'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
