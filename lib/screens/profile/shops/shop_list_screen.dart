import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../widgets/letter_avatar.dart';

class ShopListScreen extends ConsumerWidget {
  const ShopListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(allShopsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shops',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Add and manage your shops',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.shopNew),
        child: const Icon(Icons.add),
      ),
      body: shopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shops) {
          final active = shops.where((s) => s.isActive).toList();
          final inactive = shops.where((s) => !s.isActive).toList();
          final all = [...active, ...inactive];

          if (all.isEmpty) {
            return const Center(child: Text('No shops yet. Tap + to add one.'));
          }

          return ListView.separated(
            itemCount: all.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final shop = all[index];
              final isActive = shop.isActive;
              return Opacity(
                opacity: isActive ? 1.0 : 0.45,
                child: ListTile(
                  leading: LetterAvatar(name: shop.name, radius: 20),
                  title: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: shop.area != null ? Text(shop.area!) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilterChip(
                        label: Text(isActive ? 'Active' : 'Inactive'),
                        selected: isActive,
                        onSelected: (_) => ref
                            .read(databaseProvider)
                            .shopDao
                            .setShopActive(shop.id, !isActive),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => context.push('/profile/shops/${shop.id}/edit'),
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
