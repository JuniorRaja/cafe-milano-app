import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../widgets/ui/ui.dart';

class StandingOrdersScreen extends ConsumerStatefulWidget {
  const StandingOrdersScreen({super.key});

  @override
  ConsumerState<StandingOrdersScreen> createState() =>
      _StandingOrdersScreenState();
}

class _StandingOrdersScreenState extends ConsumerState<StandingOrdersScreen> {
  int? _selectedShopId;
  Map<int, TextEditingController> _controllers = {};

  /// Search hides rows. It must never rebuild or dispose the controllers —
  /// they are keyed by product id and built once per shop, and `_save` walks
  /// all of them, so a value typed into a row that is later filtered away is
  /// still there when the search is cleared and is still written on save.
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _loadingOrders = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onShopChanged(int shopId, List<Product> products) async {
    setState(() {
      _selectedShopId = shopId;
      _loadingOrders = true;
    });
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers = {};

    final orders = await ref
        .read(databaseProvider)
        .priceDao
        .watchStandingOrdersForShop(shopId)
        .first;
    final qtyMap = {for (final o in orders) o.productId: o.defaultQty};

    if (!mounted) return;
    setState(() {
      _controllers = {
        for (final p in products)
          p.id: TextEditingController(text: (qtyMap[p.id] ?? 0).toString()),
      };
      _loadingOrders = false;
    });
  }

  Future<void> _save() async {
    if (_selectedShopId == null) return;
    final dao = ref.read(databaseProvider).priceDao;
    for (final entry in _controllers.entries) {
      final qty = int.tryParse(entry.value.text.trim()) ?? 0;
      await dao.upsertStandingOrder(
        StandingOrdersCompanion(
          shopId: Value(_selectedShopId!),
          productId: Value(entry.key),
          defaultQty: Value(qty),
        ),
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Standing orders saved.')));
    }
  }

  bool _matches(Product product) {
    if (_query.isEmpty) return true;
    return product.name.toLowerCase().contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(activeShopsProvider);
    final productsAsync = ref.watch(activeProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Standing Orders',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Default quantities per shop',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: shopsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (shops) {
            if (shops.isEmpty) {
              return const Center(
                child: Text('No active shops. Add shops in Profile > Shops.'),
              );
            }
            final selectedShop = shops
                .where((s) => s.id == _selectedShopId)
                .firstOrNull;
            return productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (products) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<int>(
                      initialValue: selectedShop?.id,
                      decoration: const InputDecoration(
                        labelText: 'Select Shop',
                        border: OutlineInputBorder(),
                      ),
                      items: shops
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: s.id,
                              child: Text(
                                s.area != null
                                    ? '${s.name} · ${s.area}'
                                    : s.name,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        if (id != null) unawaited(_onShopChanged(id, products));
                      },
                    ),
                  ),
                  if (_selectedShopId == null)
                    const Expanded(
                      child: Center(
                        child: Text('Select a shop to set standing orders.'),
                      ),
                    )
                  else if (_loadingOrders)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (products.isEmpty)
                    const Expanded(
                      child: Center(child: Text('No active products.')),
                    )
                  else
                    Expanded(
                      child: _ProductQuantities(
                        products: products,
                        visible: products.where(_matches).toList(),
                        searchCtrl: _searchCtrl,
                        onQuery: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        onSave: _save,
                        controllerFor: (id) => _controllers[id],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The product list with its search box and its Save button.
///
/// [visible] is what is drawn; [products] is what exists. They differ while a
/// search is running, and the controllers are keyed off the second, never the
/// first — hiding a row must not touch the number typed into it.
class _ProductQuantities extends StatelessWidget {
  const _ProductQuantities({
    required this.products,
    required this.visible,
    required this.searchCtrl,
    required this.onQuery,
    required this.onSave,
    required this.controllerFor,
  });

  final List<Product> products;
  final List<Product> visible;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onQuery;
  final VoidCallback onSave;
  final TextEditingController? Function(int productId) controllerFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppSearchField(
          controller: searchCtrl,
          hintText: 'Search products',
          onChanged: onQuery,
        ),
        Expanded(
          child: visible.isEmpty
              ? const EmptyState.inert(
                  icon: Icons.search_off_rounded,
                  title: 'No product matches',
                  message:
                      'Try part of the name. Anything you have already '
                      'typed is kept.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = visible[index];
                    final ctrl = controllerFor(product.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.unit != null
                                  ? '${product.name} (${product.unit})'
                                  : product.name,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: '0',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSave,
              // Every product, not just the ones on screen. Named so the
              // count cannot quietly become the visible one.
              child: Text('Save all ${products.length} products'),
            ),
          ),
        ),
      ],
    );
  }
}
