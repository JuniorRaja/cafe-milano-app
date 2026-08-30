import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/widgets/product_qty_row.dart';

void main() {
  const product = Product(id: 1, name: 'Bread', isActive: true);

  Widget buildRow({
    required int qty,
    required ValueChanged<int> onQtySet,
    VoidCallback? onIncrementHold,
    VoidCallback? onDecrementHold,
  }) {
    // ProductQtyRow reads the currency symbol and digit grouping from
    // brandProvider, so it needs a scope even though nothing here is stateful.
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ProductQtyRow(
            product: product,
            qty: qty,
            price: 10,
            onIncrement: () {},
            onDecrement: () {},
            onIncrementHold: onIncrementHold,
            onDecrementHold: onDecrementHold,
            onQtySet: onQtySet,
          ),
        ),
      ),
    );
  }

  group('quantity wheel sheet', () {
    testWidgets('opens seeded on the current quantity and reads it back unchanged',
        (tester) async {
      int? result;
      await tester.pumpWidget(buildRow(qty: 250, onQtySet: (v) => result = v));

      await tester.tap(find.text('250'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(result, 250);
    });

    testWidgets('seeds each digit independently, including leading zeros',
        (tester) async {
      int? result;
      // 5 -> hundreds=0, tens=0, ones=5. A seeding bug that lets one digit's
      // wheel leak into another would show up as something other than 5.
      await tester.pumpWidget(buildRow(qty: 5, onQtySet: (v) => result = v));

      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(result, 5);
    });

    testWidgets('999 is representable without a fourth wheel', (tester) async {
      int? result;
      await tester.pumpWidget(buildRow(qty: 999, onQtySet: (v) => result = v));

      await tester.tap(find.text('999'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(result, 999);
    });
  });

  group('Input tab', () {
    testWidgets('typing a value above 999 confirms untouched from Input',
        (tester) async {
      int? result;
      await tester.pumpWidget(buildRow(qty: 10, onQtySet: (v) => result = v));

      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Input'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '5000');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(result, 5000);
    });

    testWidgets(
        'switching Input -> Wheel clamps to 999, not silently to something else',
        (tester) async {
      int? result;
      await tester.pumpWidget(buildRow(qty: 10, onQtySet: (v) => result = v));

      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Input'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '5000');

      await tester.tap(find.text('Wheel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(result, 999);
    });
  });

  group('long-press repeat', () {
    testWidgets('holding + repeats past a single tick and stops on release',
        (tester) async {
      int qty = 0;
      var ticks = 0;
      await tester.pumpWidget(buildRow(
        qty: qty,
        onQtySet: (v) => qty = v,
        onIncrementHold: () => ticks += 5,
      ));

      final plus = find.byIcon(Icons.add);
      final gesture = await tester.startGesture(tester.getCenter(plus));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pump();

      final ticksAtRelease = ticks;
      expect(ticksAtRelease, greaterThan(5)); // more than the initial tick fired

      // No repeat continues after release.
      await tester.pump(const Duration(milliseconds: 500));
      expect(ticks, ticksAtRelease);
    });

    testWidgets('disposing mid-hold leaves no pending timer', (tester) async {
      await tester.pumpWidget(buildRow(
        qty: 0,
        onQtySet: (_) {},
        onIncrementHold: () {},
      ));

      final gesture = await tester.startGesture(
          tester.getCenter(find.byIcon(Icons.add)));
      await tester.pump(const Duration(milliseconds: 600));

      // Remove the widget entirely while the repeat timer is running.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await gesture.up();

      // flutter_test fails the test on teardown if a Timer is still pending,
      // so reaching here without error is the assertion.
    });
  });
}
