import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app.dart';
import '../../../database/app_database.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../services/category_emoji.dart';
import '../../../widgets/letter_avatar.dart';

// Sentinel values for the category filter
const _kFilterAll = -2;
const _kFilterUncategorised = -1;

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  int _catFilter = _kFilterAll;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(allProductsProvider);
    final allCats = ref.watch(allCategoriesProvider).maybeWhen(
          data: (c) => c,
          orElse: () => <Category>[],
        );
    final activeCats = allCats.where((c) => c.isActive).toList();
    final catMap = {for (final c in allCats) c.id: c};

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Products',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Manage bakery product catalog',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share catalog',
            onPressed: () => context.push(AppRoutes.catalogShare),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.productNew),
        child: const Icon(Icons.add),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (products) {
          final active = products.where((p) => p.isActive).toList();
          final inactive = products.where((p) => !p.isActive).toList();
          final all = [...active, ...inactive];

          if (all.isEmpty) {
            return const Center(
                child: Text('No products yet. Tap + to add one.'));
          }

          final filtered = _applyFilter(all, catMap);

          return Column(
            children: [
              if (activeCats.isNotEmpty) _FilterChipsRow(
                categories: activeCats,
                selected: _catFilter,
                onSelect: (v) => setState(() => _catFilter = v),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final isActive = product.isActive;
                    return Opacity(
                      opacity: isActive ? 1.0 : 0.45,
                      child: ListTile(
                        leading: product.photoPath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.file(
                                  File(product.photoPath!),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      LetterAvatar(name: product.name, radius: 20),
                                ),
                              )
                            : LetterAvatar(name: product.name, radius: 20),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: _buildSubtitle(product, catMap),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilterChip(
                              label: Text(isActive ? 'Active' : 'Inactive'),
                              selected: isActive,
                              onSelected: (_) => ref
                                  .read(databaseProvider)
                                  .productDao
                                  .setProductActive(product.id, !isActive),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => context
                                  .push('/profile/products/${product.id}/edit'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List _applyFilter(List products, Map<int, Category> catMap) {
    if (_catFilter == _kFilterAll) return products;
    if (_catFilter == _kFilterUncategorised) {
      return products.where((p) => p.categoryId == null).toList();
    }
    return products.where((p) => p.categoryId == _catFilter).toList();
  }

  Widget? _buildSubtitle(Product product, Map<int, Category> catMap) {
    final unit = product.unit;
    final cat = catMap[product.categoryId];
    final parts = [
      if (unit != null && unit.isNotEmpty) 'Unit: $unit',
      if (cat != null) '${emojiFor(cat.name)} ${cat.name}',
    ];
    return parts.isEmpty ? null : Text(parts.join(' · '));
  }
}

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<Category> categories;
  final int selected;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _chip('All', _kFilterAll, selected, onSelect),
          for (final cat in categories)
            _chip(
              '${emojiFor(cat.name)} ${cat.name}',
              cat.id,
              selected,
              onSelect,
            ),
          _chip('🍽️ Uncategorised', _kFilterUncategorised, selected, onSelect),
        ],
      ),
    );
  }

  Widget _chip(String label, int value, int selected, void Function(int) onSelect) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected == value,
        onSelected: (_) => onSelect(value),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
