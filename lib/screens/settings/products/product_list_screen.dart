import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../database/app_database.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../services/category_emoji.dart';
import '../../../theme/brand_config.dart';
import '../../../utils/money.dart';
import '../../../widgets/letter_avatar.dart';
import '../../../widgets/ui/ui.dart';

/// The products master.
///
/// Same rebuild as Shops, plus the category filter it already had — now on the
/// kit's `FilterChipRow` rather than a hand-rolled chip row, and combined with
/// search rather than replaced by it.
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  /// Index into the chip row: 0 is All, then one per active category, then
  /// Uncategorised last.
  int _filterIndex = 0;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(allProductsProvider);
    final allCats = ref.watch(allCategoriesProvider).maybeWhen(
          data: (c) => c,
          orElse: () => const <Category>[],
        );
    final activeCats = allCats.where((c) => c.isActive).toList();
    final catMap = {for (final c in allCats) c.id: c};

    return MasterListPage(
      caption: 'Catalogue',
      title: 'Products',
      searchHint: 'Search products by name or category',
      actions: [
        IconButton(
          icon: const Icon(Icons.ios_share_rounded),
          color: AppColors.textPrimary,
          tooltip: 'Share catalogue',
          onPressed: () => context.push(AppRoutes.catalogShare),
        ),
      ],
      stats: productsAsync.whenOrNull(
        data: (products) {
          final active = products.where((p) => p.isActive).length;
          return [
            StatBandItem('${products.length}', label: 'products'),
            StatBandItem('$active', label: 'active'),
            StatBandItem('${activeCats.length}', label: 'categories'),
          ];
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.productNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add product'),
      ),
      builder: (context, query) => productsAsync.when(
        loading: AppSkeleton.list,
        error: (e, _) => AppErrorView(
          message: 'Could not load your products.',
          cause: '$e',
          onRetry: () => ref.invalidate(allProductsProvider),
        ),
        data: (products) {
          final ordered = [
            ...products.where((p) => p.isActive),
            ...products.where((p) => !p.isActive),
          ];
          final matches = ordered
              .where((p) => _matchesFilter(p, activeCats))
              .where((p) => _matchesQuery(p, catMap, query))
              .toList();

          return Column(
            children: [
              if (activeCats.isNotEmpty)
                FilterChipRow(
                  chips: [
                    const FilterChipData('All'),
                    for (final cat in activeCats)
                      FilterChipData('${emojiFor(cat.name)} ${cat.name}'),
                    const FilterChipData('Uncategorised'),
                  ],
                  selectedIndex: _filterIndex,
                  onSelected: (i) => setState(() => _filterIndex = i),
                ),
              Expanded(
                child: matches.isEmpty
                    ? _empty(context, query)
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                          top: AppSpace.s2,
                          bottom: 96,
                        ),
                        itemCount: matches.length,
                        itemBuilder: (context, index) => _ProductRow(
                          product: matches[index],
                          category: catMap[matches[index].categoryId],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context, String query) {
    if (query.isNotEmpty) {
      return const EmptyState.inert(
        icon: Icons.search_off_rounded,
        title: 'No product matches',
        message: 'Try part of the name, or a category.',
      );
    }
    if (_filterIndex != 0) {
      return const EmptyState.inert(
        icon: Icons.filter_alt_off_outlined,
        title: 'Nothing in this category',
        message: 'Pick another category, or All.',
      );
    }
    return EmptyState(
      icon: Icons.bakery_dining_outlined,
      title: 'No products yet',
      message: 'Add what you bake and it can be ordered, baked and billed.',
      actionLabel: 'Add your first product',
      onAction: () => context.push(AppRoutes.productNew),
    );
  }

  bool _matchesFilter(Product product, List<Category> activeCats) {
    if (_filterIndex == 0) return true;
    if (_filterIndex == activeCats.length + 1) return product.categoryId == null;
    return product.categoryId == activeCats[_filterIndex - 1].id;
  }

  bool _matchesQuery(
    Product product,
    Map<int, Category> catMap,
    String query,
  ) {
    if (query.isEmpty) return true;
    if (product.name.toLowerCase().contains(query)) return true;
    final cat = catMap[product.categoryId];
    return cat != null && cat.name.toLowerCase().contains(query);
  }
}

/// The one thing behind the ⋮. An enum rather than `void`, because
/// `PopupMenuButton` reads a null selection as a dismissal and never calls
/// `onSelected` for it.
enum _ProductAction { toggleActive }

class _ProductRow extends ConsumerWidget {
  const _ProductRow({required this.product, required this.category});

  final Product product;
  final Category? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = product.unit;
    final price = product.price;
    // Price first, because it is the field this list gets opened to check.
    // `Price not set` rather than a gap: a missing price bills the shop ₹0,
    // and a blank space does not say that.
    final parts = [
      price == null
          ? 'Price not set'
          : ref.watch(brandProvider).moneyTrim(price),
      if (unit != null && unit.isNotEmpty) unit,
      if (category != null) '${emojiFor(category!.name)} ${category!.name}',
    ];

    return ListRow(
      title: product.name,
      subtitle: parts.join(' · '),
      leading: _Thumb(product: product),
      titleBadge: product.isActive
          ? null
          : const StatusBadge(label: 'Inactive', tone: AppTone.neutral),
      onTap: () => context.push(AppRoutes.productEditFor(product.id)),
      badge: PopupMenuButton<_ProductAction>(
        icon: const Icon(
          Icons.more_vert_rounded,
          color: AppColors.textSecondary,
        ),
        tooltip: 'More actions',
        onSelected: (_) => unawaited(
          ref
              .read(databaseProvider)
              .productDao
              .setProductActive(product.id, !product.isActive),
        ),
        itemBuilder: (_) => [
          PopupMenuItem<_ProductAction>(
            value: _ProductAction.toggleActive,
            child: Text(product.isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final path = product.photoPath;
    if (path == null) return LetterAvatar(name: product.name, radius: 20);

    return ClipRRect(
      borderRadius: AppRadius.rFull,
      child: Image.file(
        File(path),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        // Product photos come from the camera. Without this the full
        // multi-megapixel image was decoded to be drawn at 40x40, on the
        // scrolling thread — a large part of why these lists stuttered.
        cacheWidth: 120,
        cacheHeight: 120,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => LetterAvatar(name: product.name, radius: 20),
      ),
    );
  }
}
