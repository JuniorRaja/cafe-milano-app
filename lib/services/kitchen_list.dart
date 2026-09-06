import '../database/app_database.dart';
import 'category_emoji.dart';

/// One product's row on the bake list: how many to make in total, across every
/// shop that ordered it today.
class KitchenItem {
  const KitchenItem({
    required this.productId,
    required this.name,
    required this.qty,
  });

  final int productId;
  final String name;
  final int qty;
}

/// A category's worth of [KitchenItem]s, in the order the kitchen bakes them.
/// Products nobody filed land in a group named `Others`, which sorts last.
class KitchenGroup {
  const KitchenGroup({
    required this.name,
    required this.emoji,
    required this.items,
  });

  final String name;
  final String emoji;
  final List<KitchenItem> items;

  int get total => items.fold(0, (sum, item) => sum + item.qty);
}

/// The name and emoji for products with no category, or one that has since been
/// deleted.
const _othersName = 'Others';

/// Collapses raw order lines into the bake list: one row per product, summed
/// across shops, grouped by category in the categories' own sort order.
///
/// The screen and the shared text both call this. They used to group
/// separately — the screen not at all — so the list the baker read and the list
/// the baker was sent could disagree about what the day's bake was.
List<KitchenGroup> groupKitchenLines({
  required List<KitchenRawLine> lines,
  required Map<int, Product> productMap,
  required List<Category> categories,
}) {
  final totals = <int, int>{};
  for (final line in lines) {
    totals[line.productId] = (totals[line.productId] ?? 0) + line.qty;
  }

  // A `null` category and an id that is no longer in `categories` mean the same
  // thing to the baker: nobody filed this product. Deleting a category must
  // never take its products off the list.
  final known = {for (final category in categories) category.id};

  final byCategory = <int?, List<KitchenItem>>{};
  for (final entry in totals.entries) {
    if (entry.value <= 0) continue;
    final product = productMap[entry.key];
    final categoryId = product?.categoryId;
    final key = known.contains(categoryId) ? categoryId : null;
    byCategory.putIfAbsent(key, () => <KitchenItem>[]).add(
          KitchenItem(
            productId: entry.key,
            name: product?.name ?? 'Product #${entry.key}',
            qty: entry.value,
          ),
        );
  }

  int byName(KitchenItem a, KitchenItem b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  final groups = <KitchenGroup>[];
  for (final category in categories) {
    final items = byCategory[category.id];
    if (items == null || items.isEmpty) continue;
    items.sort(byName);
    groups.add(KitchenGroup(
      name: category.name,
      emoji: emojiFor(category.name),
      items: items,
    ));
  }

  final others = byCategory[null];
  if (others != null && others.isNotEmpty) {
    others.sort(byName);
    groups.add(KitchenGroup(
      name: _othersName,
      emoji: emojiFor(null),
      items: others,
    ));
  }

  return groups;
}

/// The shared text for the By Item tab, built from the same [KitchenGroup] list
/// the screen draws.
String kitchenListText(List<KitchenGroup> groups, String dateLabel) {
  final buf = StringBuffer()
    ..writeln('🍞 Kitchen List — $dateLabel')
    ..writeln();
  for (final group in groups) {
    buf.writeln('${group.emoji} ${group.name} (total: ${group.total} pcs)');
    for (final item in group.items) {
      buf.writeln('· ${item.name} × ${item.qty}');
    }
    buf.writeln();
  }
  return buf.toString().trim();
}
