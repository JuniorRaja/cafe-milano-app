import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/business_info_provider.dart';
import '../../../services/catalog_share_service.dart';
import '../../../widgets/letter_avatar.dart';

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
              leading: const Icon(Icons.image_outlined),
              title: const Text('Share as Image'),
              onTap: () => Navigator.pop(ctx, CatalogShareFormat.image),
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
      final business = await ref.read(businessInfoProvider.future);
      if (format == CatalogShareFormat.pdf) {
        await shareCatalogAsPdf(business: business, products: selectedProducts);
      } else if (format == CatalogShareFormat.image) {
        await shareCatalogAsImage(business: business, products: selectedProducts);
      } else {
        await shareCatalogAsText(business: business, products: selectedProducts);
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
        actions: [
          productsAsync.maybeWhen(
            data: (products) => TextButton(
              onPressed: () => setState(() {
                _selectedIds = _selectedIds.length == products.length
                    ? {}
                    : products.map((p) => p.id).toSet();
              }),
              child: Text(_selectedIds.length == productsAsync.value?.length
                  ? 'Deselect All'
                  : 'Select All'),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
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
          return ListView.separated(
            itemCount: products.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = products[index];
              final selected = _selectedIds.contains(product.id);
              final priceLabel = product.price != null
                  ? '₹${product.price!.toStringAsFixed(product.price! == product.price!.roundToDouble() ? 0 : 2)}'
                        '${product.unit != null ? ' / ${product.unit}' : ''}'
                  : (product.unit != null ? 'per ${product.unit}' : null);
              return CheckboxListTile(
                value: selected,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedIds.add(product.id);
                  } else {
                    _selectedIds.remove(product.id);
                  }
                }),
                secondary: product.photoPath != null
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
                title: Text(product.name),
                subtitle: priceLabel != null ? Text(priceLabel) : null,
              );
            },
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
