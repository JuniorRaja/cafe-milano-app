import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app.dart';
import '../../../database/app_database.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../widgets/letter_avatar.dart';

class PriceMatrixScreen extends ConsumerStatefulWidget {
  const PriceMatrixScreen({super.key});

  @override
  ConsumerState<PriceMatrixScreen> createState() => _PriceMatrixScreenState();
}

class _PriceMatrixScreenState extends ConsumerState<PriceMatrixScreen> {
  int? _selectedShopId;
  Map<int, TextEditingController> _controllers = {};
  bool _loadingPrices = false;

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Price Matrix'),
        content: const Text(
          'Set the selling price for each product per shop. These prices are used when creating orders and generating bills.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _onShopChanged(int shopId, List<Product> products) async {
    setState(() {
      _selectedShopId = shopId;
      _loadingPrices = true;
    });
    for (final c in _controllers.values) c.dispose();
    _controllers = {};

    final prices = await ref
        .read(databaseProvider)
        .priceDao
        .watchPricesForShop(shopId)
        .first;
    final priceMap = {for (final p in prices) p.productId: p.price};

    if (!mounted) return;
    setState(() {
      _controllers = {
        for (final p in products)
          p.id: TextEditingController(
            text: priceMap.containsKey(p.id)
                ? priceMap[p.id]!.toStringAsFixed(2)
                : '',
          ),
      };
      _loadingPrices = false;
    });
  }

  Future<void> _save() async {
    if (_selectedShopId == null) return;
    final dao = ref.read(databaseProvider).priceDao;
    for (final entry in _controllers.entries) {
      final price = double.tryParse(entry.value.text.trim());
      if (price != null) {
        await dao.upsertPrice(ShopPricesCompanion(
          shopId: Value(_selectedShopId!),
          productId: Value(entry.key),
          price: Value(price),
        ));
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prices saved.')),
      );
    }
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
              'Price Matrix',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Manage product prices for each shop',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showAboutDialog(context),
            icon: const Icon(Icons.info_outline, color: kBrandBrown),
            label: const Text(
              'About',
              style: TextStyle(color: kBrandBrown),
            ),
          ),
        ],
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
                child: Text(
                    'No active shops. Add shops in Profile > Shops.'),
              );
            }
            final selectedShop =
                shops.where((s) => s.id == _selectedShopId).firstOrNull;
            return productsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
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
                                  s.area != null
                                      ? '${s.name} · ${s.area}'
                                      : s.name,
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
                      child: Center(
                          child:
                              Text('Select a shop to set prices.')),
                    )
                  else if (_loadingPrices)
                    const Expanded(
                        child: Center(
                            child: CircularProgressIndicator()))
                  else if (products.isEmpty)
                    const Expanded(
                        child: Center(
                            child: Text('No active products.')))
                  else
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: products.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final product = products[index];
                                final ctrl = _controllers[product.id];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  child: Row(
                                    children: [
                                      LetterAvatar(
                                          name: product.name,
                                          radius: 18),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          product.unit != null
                                              ? '${product.name} (${product.unit})'
                                              : product.name,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 110,
                                        child: TextField(
                                          controller: ctrl,
                                          keyboardType:
                                              const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                          decoration:
                                              const InputDecoration(
                                            prefixText: '₹',
                                            hintText: '—',
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                EdgeInsets.symmetric(
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
      ),
    );
  }
}
