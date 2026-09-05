// The billing screen's bill card and its share picker.
//
// Two things here are worth a test rather than a look. The card was one row
// with a `FittedBox` scaling the status chips down until they fitted beside the
// money — so the layout got worse as the totals got longer. And `Share All
// Bills` could only share everything, so nothing had to agree with anything.
// Now the owner picks, and the GRAND TOTAL must be the total of what was
// picked. See docs/features/10b-device-pass.md, G1 and G2.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milano_orders/database/app_database.dart';
import 'package:milano_orders/providers/ledger_provider.dart';
import 'package:milano_orders/providers/order_provider.dart';
import 'package:milano_orders/providers/product_provider.dart';
import 'package:milano_orders/providers/shop_provider.dart';
import 'package:milano_orders/screens/orders/orders_screen.dart';
import 'package:milano_orders/services/bill_share.dart';
import 'package:milano_orders/theme/app_theme.dart';
import 'package:milano_orders/theme/brand_config.dart';

void main() {
  final today = DateTime.now();
  final day = DateTime(today.year, today.month, today.day);

  Shop shop(int id, String name, {String? area}) =>
      Shop(id: id, name: name, area: area, phone: null, isActive: true);

  OrderDaySummary bill(int id, int shopId, double total, {int items = 3}) =>
      OrderDaySummary(
        order: DailyOrder(
          id: id,
          shopId: shopId,
          orderDate: day,
          isConfirmed: true,
        ),
        itemCount: items,
        total: total,
      );

  BillDue due(double total, double allocated, BillStatus status) =>
      BillDue(total: total, allocated: allocated, status: status);

  Widget buildBilling({
    List<OrderDaySummary> bills = const [],
    List<Shop> shops = const [],
    Map<int, BillDue> dues = const {},
    OrderWithLines? lines,
  }) {
    return ProviderScope(
      overrides: [
        orderSummariesForDateProvider
            .overrideWith((ref, date) => Stream.value(bills)),
        allShopsProvider.overrideWith((ref) => Stream.value(shops)),
        allProductsProvider.overrideWith((ref) => Stream.value(const [])),
        billDuesForDateProvider.overrideWith((ref, date) => Stream.value(dues)),
        orderWithLinesProvider
            .overrideWith((ref, orderId) => Stream.value(lines)),
      ],
      child: MaterialApp(
        theme: buildAppTheme(BrandConfig.milano),
        home: const OrdersScreen(),
      ),
    );
  }

  group('the bill card', () {
    testWidgets('carries the shop, its area, the total and the size',
        (tester) async {
      // Two bills, so the card's own total is not also the grand total.
      await tester.pumpWidget(buildBilling(
        bills: [bill(1, 1, 450, items: 7), bill(2, 2, 90)],
        shops: [
          shop(1, 'Hotel Raj', area: 'Anna Nagar'),
          shop(2, 'Star Bakery'),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Hotel Raj'), findsOneWidget);
      expect(find.text('Anna Nagar'), findsOneWidget);
      expect(find.text('₹450'), findsOneWidget);
      expect(find.text('7 items'), findsOneWidget);
    });

    testWidgets('says what is owed when the bill is not settled',
        (tester) async {
      await tester.pumpWidget(buildBilling(
        bills: [bill(1, 1, 450)],
        shops: [shop(1, 'Hotel Raj')],
        dues: {1: due(450, 100, BillStatus.partial)},
      ));
      await tester.pumpAndSettle();

      expect(find.text('₹350 due'), findsOneWidget);
      expect(find.text('Partial'), findsOneWidget);
      // The size of the order is the fallback, not the headline, when there is
      // money outstanding.
      expect(find.text('3 items'), findsNothing);
    });

    testWidgets('a paid bill shows its size, not a zero owing',
        (tester) async {
      await tester.pumpWidget(buildBilling(
        bills: [bill(1, 1, 450)],
        shops: [shop(1, 'Hotel Raj')],
        dues: {1: due(450, 450, BillStatus.paid)},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('3 items'), findsOneWidget);
      expect(find.text('₹0 due'), findsNothing);
    });

    testWidgets('both status pills sit on the strip, under the money',
        (tester) async {
      await tester.pumpWidget(buildBilling(
        bills: [bill(1, 1, 450)],
        shops: [shop(1, 'Hotel Raj')],
        dues: {1: due(450, 0, BillStatus.unpaid)},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Unpaid'), findsOneWidget);
      // The workaround the strip exists to delete.
      expect(find.byType(FittedBox), findsNothing);
    });

    testWidgets('the caret expands and collapses the line items',
        (tester) async {
      await tester.pumpWidget(buildBilling(
        bills: [bill(1, 1, 450)],
        shops: [shop(1, 'Hotel Raj')],
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.expand_more_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.expand_less_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    });

    testWidgets('the grand total is the day, whatever is picked later',
        (tester) async {
      await tester.pumpWidget(buildBilling(
        bills: [bill(1, 1, 450), bill(2, 2, 550)],
        shops: [shop(1, 'Hotel Raj'), shop(2, 'Star Bakery')],
      ));
      await tester.pumpAndSettle();

      expect(find.text('GRAND TOTAL'), findsOneWidget);
      expect(find.text('₹1,000'), findsOneWidget);
    });
  });

  group('Share bills', () {
    testWidgets('opens a picker listing every bill, all ticked',
        (tester) async {
      await tester.pumpWidget(buildBilling(
        bills: [bill(1, 1, 450), bill(2, 2, 550)],
        shops: [shop(1, 'Hotel Raj'), shop(2, 'Star Bakery')],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Share bills'));
      await tester.pumpAndSettle();

      expect(find.text('2 of 2 shops'), findsOneWidget);
      expect(find.text('Share 2 bills'), findsOneWidget);
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((c) => c.value == true),
        isTrue,
      );
    });

    testWidgets('unticking one narrows the count and the button',
        (tester) async {
      await tester.pumpWidget(buildBilling(
        bills: [bill(1, 1, 450), bill(2, 2, 550)],
        shops: [shop(1, 'Hotel Raj'), shop(2, 'Star Bakery')],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Share bills'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(CheckboxListTile),
        matching: find.text('Star Bakery'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('1 of 2 shops'), findsOneWidget);
      expect(find.text('Share 1 bill'), findsOneWidget);
    });

    testWidgets('picking nothing cannot be shared', (tester) async {
      await tester.pumpWidget(buildBilling(
        bills: [bill(1, 1, 450)],
        shops: [shop(1, 'Hotel Raj')],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Share bills'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('0 of 1 shops'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('billsSummaryText', () {
    test('totals what was picked, not what the day holds', () {
      // The whole point of G2. Two of the day's three shops go out, and the
      // figure at the bottom is those two.
      final text = billsSummaryText(
        bills: [bill(1, 1, 450), bill(2, 2, 550)],
        shopMap: {
          1: shop(1, 'Hotel Raj'),
          2: shop(2, 'Star Bakery'),
          3: shop(3, 'Left Out'),
        },
        brand: BrandConfig.milano,
        dateLabel: '05 Sep 2026',
      );

      expect(text, contains('🏪 Hotel Raj — ₹450'));
      expect(text, contains('🏪 Star Bakery — ₹550'));
      expect(text, isNot(contains('Left Out')));
      expect(text, contains('GRAND TOTAL: ₹1,000'));
    });

    test('a shop that is gone is named, not left blank', () {
      final text = billsSummaryText(
        bills: [bill(1, 9, 100)],
        shopMap: const {},
        brand: BrandConfig.milano,
        dateLabel: '05 Sep 2026',
      );

      expect(text, contains('🏪 Unknown — ₹100'));
    });
  });

  group('billDetailText', () {
    OrderLine line(int productId, int qty, double unitPrice) => OrderLine(
          id: productId,
          orderId: 1,
          productId: productId,
          qty: qty,
          unitPrice: unitPrice,
        );

    Product product(int id, String name) => Product(
          id: id,
          name: name,
          unit: null,
          photoPath: null,
          isActive: true,
        );

    test('itemises alphabetically and totals the lines', () {
      final text = billDetailText(
        shopName: 'Hotel Raj',
        order: OrderWithLines(
          order: DailyOrder(
            id: 1,
            shopId: 1,
            orderDate: day,
            isConfirmed: true,
          ),
          lines: [line(1, 2, 40), line(2, 3, 10)],
        ),
        productMap: {1: product(1, 'Zebra Cake'), 2: product(2, 'Almond Bun')},
        brand: BrandConfig.milano,
        dateLabel: '05 Sep 2026',
      );

      expect(
        text,
        '🧾 Bill — Hotel Raj\n'
        'Date: 05 Sep 2026\n'
        '\n'
        '· Almond Bun × 3 — ₹30\n'
        '· Zebra Cake × 2 — ₹80\n'
        '\n'
        'TOTAL: ₹110',
      );
    });

    test('an empty order says so rather than sending a blank bill', () {
      final text = billDetailText(
        shopName: 'Hotel Raj',
        order: null,
        productMap: const {},
        brand: BrandConfig.milano,
        dateLabel: '05 Sep 2026',
      );

      expect(text, endsWith('No items'));
    });
  });
}
