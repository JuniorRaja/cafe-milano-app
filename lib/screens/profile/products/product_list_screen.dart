import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/database_provider.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(allProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
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
            return const Center(child: Text('No products yet. Tap + to add one.'));
          }

          return ListView.separated(
            itemCount: all.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = all[index];
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
                            errorBuilder: (_, __, ___) => const CircleAvatar(
                              child: Icon(Icons.bakery_dining),
                            ),
                          ),
                        )
                      : const CircleAvatar(child: Icon(Icons.bakery_dining)),
                  title: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: product.unit != null ? Text('Unit: ${product.unit}') : null,
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
                        onPressed: () =>
                            context.push('/profile/products/${product.id}/edit'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
