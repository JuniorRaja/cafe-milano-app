import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/database_provider.dart';

class StandingOrdersScreen extends ConsumerStatefulWidget {
  const StandingOrdersScreen({super.key});

  @override
  ConsumerState<StandingOrdersScreen> createState() => _StandingOrdersScreenState();
}

class _StandingOrdersScreenState extends ConsumerState<StandingOrdersScreen> {
  int? _selectedShopId;
  Map<int, TextEditingController> _controllers = {};
  bool _loadingOrders = false;

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _onShopChanged(int shopId, List<Product> products) async {
    setState(() {
      _selectedShopId = shopId;
      _loadingOrders = true;
    });
    for (final c in _controllers.values) c.dispose();
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
          p.id: TextEditingController(
            text: (qtyMap[p.id] ?? 0).toString(),
          ),
      };
      _loadingOrders = false;
    });
  }

  Future<void> _save() async {
    if (_selectedShopId == null) return;
    final dao = ref.read(databaseProvider).priceDao;
    for (final entry in _controllers.entries) {
      final qty = int.tryParse(entry.value.text.trim()) ?? 0;
      await dao.upsertStandingOrder(StandingOrdersCompanion(
        shopId: Value(_selectedShopId!),
        productId: Value(entry.key),
        defaultQty: Value(qty),
      ));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Standing orders saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(activeShopsProvider);
    final productsAsync = ref.watch(activeProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Standing Orders')),
      body: shopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shops) {
          if (shops.isEmpty) {
            return const Center(
              child: Text('No active shops. Add shops in Profile > Shops.'),
            );
          }
          final selectedShop = shops.where((s) => s.id == _selectedShopId).firstOrNull;
          return productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (products) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<int>(
                    value: selectedShop?.id,
                    decoration: const InputDecoration(
                      labelText: 'Select Shop',
                      border: OutlineInputBorder(),
                    ),
                    items: shops
                        .map((s) => DropdownMenuItem<int>(
                              value: s.id,
                              child: Text(
                                s.area != null ? '${s.name} · ${s.area}' : s.name,
                              ),
                            ))
                        .toList(),
                    onChanged: (id) {
                      if (id != null) _onShopChanged(id, products);
                    },
                  ),
                ),
                if (_selectedShopId == null)
                  const Expanded(
                    child: Center(child: Text('Select a shop to set standing orders.')),
                  )
                else if (_loadingOrders)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (products.isEmpty)
                  const Expanded(child: Center(child: Text('No active products.')))
                else
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: products.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final product = products[index];
                              final ctrl = _controllers[product.id];
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
                              onPressed: _save,
                              child: const Text('Save Changes'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
