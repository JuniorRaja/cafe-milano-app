import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../services/category_emoji.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(allCategoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Group and organise your products',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => catsAsync.whenData(
          (cats) => _addCategory(context, ref, cats),
        ),
        child: const Icon(Icons.add),
      ),
      body: catsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cats) {
          if (cats.isEmpty) {
            return const Center(
              child: Text('No categories yet. Tap + to add one.'),
            );
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            onReorderItem: (oldIndex, newIndex) =>
                _onReorder(ref, cats, oldIndex, newIndex),
            itemCount: cats.length,
            itemBuilder: (context, i) {
              final cat = cats[i];
              return _CategoryTile(
                key: ValueKey(cat.id),
                category: cat,
                onEdit: () => _editCategory(context, ref, cat),
                onDelete: () => _deleteCategory(context, ref, cat),
                onToggleActive: () => ref
                    .read(databaseProvider)
                    .categoryDao
                    .setActive(cat.id, !cat.isActive),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addCategory(
      BuildContext context, WidgetRef ref, List<Category> current) async {
    final name = await _showNameDialog(context, null);
    if (name == null) return;
    final sortOrder = current.isEmpty ? 0 : (current.last.sortOrder + 1);
    await ref.read(databaseProvider).categoryDao.insertCategory(name, sortOrder);
  }

  Future<void> _editCategory(
      BuildContext context, WidgetRef ref, Category cat) async {
    final name = await _showNameDialog(context, cat.name);
    if (name == null) return;
    await ref.read(databaseProvider).categoryDao.renameCategory(cat.id, name);
  }

  Future<String?> _showNameDialog(BuildContext context, String? initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial == null ? 'Add Category' : 'Rename Category'),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(
      BuildContext context, WidgetRef ref, Category cat) async {
    final db = ref.read(databaseProvider);
    final count = await db.categoryDao.countProductsForCategory(cat.id);
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          count > 0
              ? '$count ${count == 1 ? "product" : "products"} will become uncategorised. Continue?'
              : 'Delete "${cat.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(databaseProvider).categoryDao.deleteCategory(cat.id);
    }
  }

  Future<void> _onReorder(
      WidgetRef ref, List<Category> cats, int oldIndex, int newIndex) async {
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final emoji = emojiFor(category.name);
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 22)),
      title: Text(
        category.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: category.isActive ? null : Colors.grey,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilterChip(
            label: Text(category.isActive ? 'Active' : 'Inactive',
                style: const TextStyle(fontSize: 12)),
            selected: category.isActive,
            onSelected: (_) => onToggleActive(),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onEdit,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
