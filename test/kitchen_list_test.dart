// The bake list: raw order lines in, grouped kitchen list out.
//
// This function exists because the screen and the shared text used to group
// separately — the screen not at all. Two renderers, one grouping, so the list
// the baker reads and the list the baker is sent can never disagree.
// See docs/features/10b-device-pass.md, F2.
import 'package:flutter_test/flutter_test.dart';
import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/services/kitchen_list.dart';

void main() {
  Category cat(int id, String name, int sortOrder) =>
      Category(id: id, name: name, sortOrder: sortOrder, isActive: true);

  Product product(int id, String name, {int? categoryId}) => Product(
        id: id,
        name: name,
        unit: 'pc',
        photoPath: null,
        isActive: true,
        categoryId: categoryId,
      );

  KitchenRawLine line(int shopId, int productId, int qty) =>
      KitchenRawLine(shopId: shopId, productId: productId, qty: qty);

  /// Named `bake` and not `group` because `group` is the test one.
  List<KitchenGroup> bake(
    List<KitchenRawLine> lines,
    List<Product> products,
    List<Category> categories,
  ) =>
      groupKitchenLines(
        lines: lines,
        productMap: {for (final p in products) p.id: p},
        categories: categories,
      );

  group('groupKitchenLines', () {
    test('sums one product across every shop that ordered it', () {
      final groups = bake(
        [line(1, 1, 30), line(2, 1, 20), line(3, 1, 5)],
        [product(1, 'Bun', categoryId: 1)],
        [cat(1, 'Bread', 0)],
      );

      expect(groups, hasLength(1));
      expect(groups.single.items, hasLength(1));
      expect(groups.single.items.single.qty, 55);
      expect(groups.single.total, 55);
    });

    test('groups by category, in the categories own sort order', () {
      final groups = bake(
        [line(1, 1, 10), line(1, 2, 20)],
        [
          product(1, 'Cake', categoryId: 2),
          product(2, 'Bun', categoryId: 1),
        ],
        // Bread sorts first even though the Cake line came first.
        [cat(1, 'Bread', 0), cat(2, 'Cakes', 1)],
      );

      expect(groups.map((g) => g.name), ['Bread', 'Cakes']);
      expect(groups.first.items.single.name, 'Bun');
    });

    test('a category nobody ordered from is left out', () {
      final groups = bake(
        [line(1, 1, 10)],
        [product(1, 'Bun', categoryId: 1)],
        [cat(1, 'Bread', 0), cat(2, 'Cakes', 1)],
      );

      expect(groups.map((g) => g.name), ['Bread']);
    });

    test('uncategorised products fall into Others, last', () {
      final groups = bake(
        [line(1, 1, 10), line(1, 2, 3)],
        [product(1, 'Loose Item'), product(2, 'Bun', categoryId: 1)],
        [cat(1, 'Bread', 0)],
      );

      expect(groups.map((g) => g.name), ['Bread', 'Others']);
      expect(groups.last.items.single.name, 'Loose Item');
    });

    test('a product filed under a deleted category still reaches the list', () {
      // The category id survives on the product after the category is gone.
      // Dropping the row would take the item out of the day's bake.
      final groups = bake(
        [line(1, 1, 12)],
        [product(1, 'Orphan', categoryId: 99)],
        [cat(1, 'Bread', 0)],
      );

      expect(groups.map((g) => g.name), ['Others']);
      expect(groups.single.items.single.qty, 12);
    });

    test('items inside a group are alphabetical, case-insensitively', () {
      final groups = bake(
        [line(1, 1, 1), line(1, 2, 1), line(1, 3, 1)],
        [
          product(1, 'zebra bun', categoryId: 1),
          product(2, 'Almond Bun', categoryId: 1),
          product(3, 'mango bun', categoryId: 1),
        ],
        [cat(1, 'Bread', 0)],
      );

      expect(
        groups.single.items.map((i) => i.name),
        ['Almond Bun', 'mango bun', 'zebra bun'],
      );
    });

    test('a zero quantity is not a bake instruction', () {
      final groups = bake(
        [line(1, 1, 0), line(1, 2, 4)],
        [
          product(1, 'Bun', categoryId: 1),
          product(2, 'Roll', categoryId: 1),
        ],
        [cat(1, 'Bread', 0)],
      );

      expect(groups.single.items.map((i) => i.name), ['Roll']);
    });

    test('quantities that cancel out across shops drop the row', () {
      // A correction line can be negative. Net zero means nothing to bake.
      final groups = bake(
        [line(1, 1, 6), line(2, 1, -6)],
        [product(1, 'Bun', categoryId: 1)],
        [cat(1, 'Bread', 0)],
      );

      expect(groups, isEmpty);
    });

    test('a product missing from the map is named, not dropped', () {
      final groups = bake([line(1, 7, 3)], [], []);

      expect(groups.single.items.single.name, 'Product #7');
    });
  });

  group('kitchenListText', () {
    test('renders the same grouping the screen draws', () {
      final groups = bake(
        [line(1, 1, 30), line(2, 1, 20), line(1, 2, 4)],
        [product(1, 'Bun', categoryId: 1), product(2, 'Loose Item')],
        [cat(1, 'Bread', 0)],
      );

      expect(
        kitchenListText(groups, '05 Sep 2026'),
        '🍞 Kitchen List — 05 Sep 2026\n'
        '\n'
        '🥖 Bread (total: 50 pcs)\n'
        '· Bun × 50\n'
        '\n'
        '🍽️ Others (total: 4 pcs)\n'
        '· Loose Item × 4',
      );
    });

    test('an empty day is a header and nothing else', () {
      expect(
        kitchenListText(const [], '05 Sep 2026'),
        '🍞 Kitchen List — 05 Sep 2026',
      );
    });
  });
}
