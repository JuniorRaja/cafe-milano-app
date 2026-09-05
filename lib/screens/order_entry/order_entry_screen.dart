import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/pending_writes.dart';
import '../../utils/haptics.dart';
import '../../widgets/product_qty_row.dart';
import '../../utils/money.dart';
import '../../theme/brand_config.dart';
import '../../widgets/ui/ui.dart';

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

  // Held rather than read on demand: dispose() flushes a pending save, and
  // `ref` is already unusable by then.
  late final AppDatabase _db;

  /// Removes this screen's entry from [pendingWritesProvider].
  VoidCallback? _unregisterFlush;

  @override
  void initState() {
    super.initState();
    _db = ref.read(databaseProvider);
    // dispose() covers leaving the screen. This covers the app being
    // backgrounded, where Android may suspend or kill the process without
    // ever calling dispose — same 500 ms of typing, same data loss.
    _unregisterFlush = ref.read(pendingWritesProvider).register(_flushPending);
    if (widget.date != null) {
      final p = widget.date!.split('-');
      _date = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } else {
      final now = DateTime.now();
      _date = DateTime(now.year, now.month, now.day);
    }
    unawaited(_init());
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

    final prods = (results[0] as List<Product>)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

  /// Writes a debounced save immediately, if one is pending. Safe to call when
  /// nothing is outstanding — it is then a no-op.
  ///
  /// The write goes through `_db`, not `ref`: `ref` is dead by dispose() and
  /// `_save()` would fail silently, which is the same data loss wearing a
  /// different hat.
  Future<void> _flushPending() async {
    if (!(_debounce?.isActive ?? false)) return;
    _debounce!.cancel();
    await _save();
  }

  @override
  void dispose() {
    _unregisterFlush?.call();
    // Flush, do not discard. Anything typed in the last 500 ms is otherwise
    // lost on the way out of this screen.
    unawaited(_flushPending().catchError((Object e) {
      debugPrint('[MilanoOrders] order-entry flush failed: $e');
    }));
    super.dispose();
  }

  void _setQty(int productId, int qty) {
    setState(() {
      _qtys[productId] = qty;
      if (_isConfirmed) {
        _isConfirmed = false;
        // A DB write inside setState. The OrderDraftController refactor
        // in doc 10c owns this; wrapping it in unawaited() here would
        // hide the defect rather than mark it.
        // ignore: discarded_futures
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
              unitPrice: Value(_priceMap[p.id] ??
                  p.price ??
                  _snapshotPrices[p.id] ??
                  0.0),
            ))
        .toList();
    await _db.orderDao.replaceOrderLines(_orderId!, lines);
  }

  Future<void> _confirmOrder() async {
    _debounce?.cancel();
    final totalQty = _qtys.values.fold(0, (a, b) => a + b);
    if (totalQty == 0) {
      final ok = await confirmDestructive(
        context,
        title: 'All quantities are 0',
        message: 'Confirm this order with no items?',
        confirmLabel: 'Confirm',
        destructive: false,
      );
      if (!ok || !mounted) return;
    }
    await _save();
    if (!mounted) return;
    await ref.read(databaseProvider).orderDao.setConfirmed(_orderId!, true);
    if (!mounted) return;
    unawaited(AppHaptics.success());
    setState(() => _isConfirmed = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kBrandBrown,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: const Icon(Icons.check_circle, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Order confirmed'),
          ],
        ),
      ),
    );
    // Confirming is the end of this shop. Going back was a second tap on every
    // shop, every morning. The snackbar lives on the app's ScaffoldMessenger,
    // so it survives the pop and is read on the list.
    context.pop();
  }

  Future<void> _loadStandingOrder() async {
    final hasEntries = _qtys.values.any((q) => q > 0);
    if (hasEntries) {
      final ok = await confirmDestructive(
        context,
        title: 'Load Standing Order',
        message: 'Replace current entries with standing order quantities?',
        detail: 'This cannot be undone.',
        confirmLabel: 'Replace',
      );
      if (!ok || !mounted) return;
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
        // Same defect as in _setQty. Doc 10c.
        // ignore: discarded_futures
        db.orderDao.setConfirmed(_orderId!, false);
      }
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  /// Leaves this screen the way the user arrived.
  ///
  /// This used to jump to `/` — which is not a back at all. It goes to the
  /// Overview branch, so leaving a shop landed on the Dashboard rather than on
  /// the Orders tab the shop was opened from. It was also a hardcoded route
  /// string, which AGENTS.md rule 10 forbids for exactly this reason.
  ///
  /// The fallback covers a cold deep link into `/order/5`, where there is no
  /// stack to pop. Orders is where this screen is reached from, so that is
  /// where an unpoppable one goes — never the Overview.
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.orders);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _back,
          ),
          title: const Text('Order Entry'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final dateLabel = DateFormat('dd MMM yyyy, EEE').format(_date);
    final unpricedCount =
        _products.where((p) => (_priceMap[p.id] ?? p.price) == null).length;
    final pricedCount = _products.length - unpricedCount;

    int totalItems = 0;
    double totalAmount = 0;
    for (final p in _products) {
      final qty = _qtys[p.id] ?? 0;
      final price = _priceMap[p.id] ?? p.price;
      if (qty > 0 && price != null) {
        totalItems += qty;
        totalAmount += qty * price;
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
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
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (context, i) {
                      final product = _products[i];
                      final price = _priceMap[product.id] ?? product.price;
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
                        onDecrementHold: price != null
                            ? () => _setQty(
                                product.id, (qty - 5).clamp(0, 9999))
                            : null,
                        onIncrementHold: price != null
                            ? () => _setQty(
                                product.id, (qty + 5).clamp(0, 9999))
                            : null,
                        onQtySet: price != null
                            ? (v) => _setQty(product.id, v.clamp(0, 9999))
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
                          ref.watch(brandProvider).moneyTrim(totalAmount),
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
