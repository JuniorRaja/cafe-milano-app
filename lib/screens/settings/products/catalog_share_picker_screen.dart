import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/business_info_provider.dart';
import '../../../services/catalog_share_service.dart';
import '../../../widgets/letter_avatar.dart';
import '../../../widgets/ui/ui.dart';

class CatalogSharePickerScreen extends ConsumerStatefulWidget {
  const CatalogSharePickerScreen({super.key});

  @override
  ConsumerState<CatalogSharePickerScreen> createState() =>
      _CatalogSharePickerScreenState();
}

class _CatalogSharePickerScreenState
    extends ConsumerState<CatalogSharePickerScreen> {
  Set<int> _selectedIds = {};
  bool _initialized = false;
  bool _generating = false;

  Future<void> _chooseFormat(List<Product> selectedProducts) async {
    final format = await showModalBottomSheet<CatalogShareFormat>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Share as PDF'),
              onTap: () => Navigator.pop(ctx, CatalogShareFormat.pdf),
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('Share as Text'),
              onTap: () => Navigator.pop(ctx, CatalogShareFormat.text),
            ),
          ],
        ),
      ),
    );
    if (format == null || !mounted) return;

    setState(() => _generating = true);
    try {
      final business   = await ref.read(businessInfoProvider.future);
      final categories = await ref.read(activeCategoriesProvider.future);
      if (format == CatalogShareFormat.pdf) {
        await shareCatalogAsPdf(business: business, products: selectedProducts, categories: categories);
      } else {
        await shareCatalogAsText(business: business, products: selectedProducts, categories: categories);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share catalog: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String? _priceLabel(Product product) {
    if (product.price == null) {
      return product.unit != null ? 'per ${product.unit}' : null;
    }
    final price = product.price!;
    final text = price == price.roundToDouble()
        ? price.toStringAsFixed(0)
        : price.toStringAsFixed(2);
    return '\u{20B9}$text${product.unit != null ? ' / ${product.unit}' : ''}';
  }

  Widget _thumb(Product product) {
    final path = product.photoPath;
    if (path == null) return LetterAvatar(name: product.name, radius: 20);
    return ClipRRect(
      borderRadius: AppRadius.rFull,
      child: Image.file(
        File(path),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        cacheWidth: 120,
        cacheHeight: 120,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => LetterAvatar(name: product.name, radius: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(activeProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share Catalog',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Select the products to include',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (products) {
          if (!_initialized) {
            _selectedIds = products.map((p) => p.id).toSet();
            _initialized = true;
          }
          if (products.isEmpty) {
            return const Center(child: Text('No active products to share.'));
          }
          return MultiSelectList(
            noun: 'products',
            options: [
              for (final product in products)
                SelectOption(
                  id: product.id,
                  title: product.name,
                  subtitle: _priceLabel(product),
                  leading: _thumb(product),
                ),
            ],
            selected: _selectedIds,
            onChanged: (next) => setState(() => _selectedIds = next),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _selectedIds.isEmpty || _generating
                ? null
                : () => _chooseFormat(
                      (productsAsync.value ?? [])
                          .where((p) => _selectedIds.contains(p.id))
                          .toList(),
                    ),
            child: _generating
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('Share (${_selectedIds.length} selected)'),
          ),
        ),
      ),
    );
  }
}
