import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../services/category_emoji.dart';
import '../../../widgets/ui/ui.dart';

/// The categories master.
///
/// This was the odd one out: no header block, an emoji where the other two
/// masters put an avatar, a grey title instead of a badge for inactive, and
/// three icon buttons per row. It now reads as the same screen as Shops and
/// Products, and shows the one number that makes a category meaningful — how
/// many products are in it.
///
/// Reordering is kept, because sort order is what drives the kitchen list, but
/// the drag handle only appears while the list is unfiltered: reordering a
/// filtered subset would write positions the user cannot see.
class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(allCategoriesProvider);
    final products = ref.watch(allProductsProvider).maybeWhen(
          data: (p) => p,
          orElse: () => const <Product>[],
        );

    // One pass over the products, not a query per category.
    final counts = <int?, int>{};
    for (final product in products) {
      counts[product.categoryId] = (counts[product.categoryId] ?? 0) + 1;
    }

    return MasterListPage(
      caption: 'Catalogue',
      title: 'Categories',
      searchHint: 'Search categories',
      stats: catsAsync.whenOrNull(
        data: (cats) => [
          StatBandItem('${cats.length}', label: 'categories'),
          StatBandItem('${cats.where((c) => c.isActive).length}', label: 'active'),
          if ((counts[null] ?? 0) > 0)
            StatBandItem(
              '${counts[null]}',
              label: 'uncategorised',
              tone: AppTone.warning,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => catsAsync.whenData(
          (cats) => _addCategory(context, ref, cats),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add category'),
      ),
      builder: (context, query) => catsAsync.when(
        loading: AppSkeleton.list,
        error: (e, _) => AppErrorView(
          message: 'Could not load your categories.',
          cause: '$e',
          onRetry: () => ref.invalidate(allCategoriesProvider),
        ),
        data: (cats) {
          final matches = cats
              .where((c) => query.isEmpty || c.name.toLowerCase().contains(query))
              .toList();

          if (matches.isEmpty) {
            return query.isEmpty
                ? EmptyState(
                    icon: Icons.category_outlined,
                    title: 'No categories yet',
                    message: 'Group your products so the kitchen list and the '
                        'dashboard read in a sensible order.',
                    actionLabel: 'Add your first category',
                    onAction: () => _addCategory(context, ref, cats),
                  )
                : const EmptyState.inert(
                    icon: Icons.search_off_rounded,
                    title: 'No category matches',
                    message: 'Try part of the name.',
                  );
          }

          Widget rowFor(Category cat) => _CategoryRow(
                key: ValueKey(cat.id),
                category: cat,
                productCount: counts[cat.id] ?? 0,
                onEdit: () => _editCategory(context, ref, cat),
                onDelete: () => _deleteCategory(context, ref, cat),
              );

          const padding = EdgeInsets.only(top: AppSpace.s2, bottom: 96);

          // Drag-to-reorder writes absolute positions, so it is only offered
          // when what is on screen is the whole list in its real order.
          if (query.isNotEmpty) {
            return ListView.builder(
              padding: padding,
              itemCount: matches.length,
              itemBuilder: (context, i) => rowFor(matches[i]),
            );
          }

          return ReorderableListView.builder(
            padding: padding,
            onReorderItem: (oldIndex, newIndex) =>
                _onReorder(ref, matches, oldIndex, newIndex),
            itemCount: matches.length,
            itemBuilder: (context, i) => rowFor(matches[i]),
          );
        },
      ),
    );
  }

  Future<void> _addCategory(
    BuildContext context,
    WidgetRef ref,
    List<Category> current,
  ) async {
    final name = await _showNameDialog(context, null);
    if (name == null) return;
    final sortOrder = current.isEmpty ? 0 : (current.last.sortOrder + 1);
    await ref.read(databaseProvider).categoryDao.insertCategory(name, sortOrder);
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref,
    Category cat,
  ) async {
    final name = await _showNameDialog(context, cat.name);
    if (name == null) return;
    await ref.read(databaseProvider).categoryDao.renameCategory(cat.id, name);
  }

  Future<String?> _showNameDialog(BuildContext context, String? initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rM),
        title: Text(
          initial == null ? 'Add Category' : 'Rename Category',
          style: AppType.titleM,
        ),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Category name'),
          autofocus: true,
          onSubmitted: (v) {
            final trimmed = v.trim();
            if (trimmed.isNotEmpty) Navigator.pop(ctx, trimmed);
          },
        ),
        actions: [
          AppButton.text(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
          AppButton(
            label: 'Save',
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    Category cat,
  ) async {
    final db = ref.read(databaseProvider);
    final count = await db.categoryDao.countProductsForCategory(cat.id);
    if (!context.mounted) return;
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete Category',
      message: 'Delete "${cat.name}"?',
      detail: count == 0
          ? null
          : '$count ${count == 1 ? 'product' : 'products'} will become '
              'uncategorised.',
    );
    if (confirmed && context.mounted) {
      await db.categoryDao.deleteCategory(cat.id);
    }
  }

  Future<void> _onReorder(
    WidgetRef ref,
    List<Category> cats,
    int oldIndex,
    int newIndex,
  ) async {
    final reordered = [...cats];
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    final dao = ref.read(databaseProvider).categoryDao;
    for (var i = 0; i < reordered.length; i++) {
      if (reordered[i].sortOrder != i) {
        await dao.reorderCategory(reordered[i].id, i);
      }
    }
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({
    super.key,
    required this.category,
    required this.productCount,
    required this.onEdit,
    required this.onDelete,
  });

  final Category category;
  final int productCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListRow(
      title: category.name,
      subtitle: productCount == 0
          ? 'No products yet'
          : '$productCount ${productCount == 1 ? 'product' : 'products'}',
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.surfaceMuted,
          shape: BoxShape.circle,
        ),
        child: Text(emojiFor(category.name), style: AppType.titleM),
      ),
      badge: category.isActive
          ? null
          : const StatusBadge(label: 'Inactive', tone: AppTone.neutral),
      onTap: onEdit,
      footer: Padding(
        padding: const EdgeInsets.only(top: AppSpace.s2),
        // Two actions, not three. Tapping the row already renames, and a
        // third button overflowed the row on a 420pt screen — Rename was the
        // one that was already reachable another way.
        child: Row(
          children: [
            AppButton.text(label: 'Delete', onPressed: onDelete),
            const Spacer(),
            AppButton.text(
              label: category.isActive ? 'Deactivate' : 'Activate',
              onPressed: () => ref
                  .read(databaseProvider)
                  .categoryDao
                  .setActive(category.id, !category.isActive),
            ),
          ],
        ),
      ),
    );
  }
}
