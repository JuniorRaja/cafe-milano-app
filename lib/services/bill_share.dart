import '../database/app_database.dart';
import '../theme/brand_config.dart';
import '../utils/money.dart';

/// The day's bills as one message: a line per shop, then the total of the
/// lines above it.
///
/// [bills] is what the owner picked, not what the day holds. The total is
/// computed from the same list that is printed, because a share of three of
/// eight shops carrying the eight-shop figure is a wrong number sent to a
/// customer.
String billsSummaryText({
  required List<OrderDaySummary> bills,
  required Map<int, Shop> shopMap,
  required BrandConfig brand,
  required String dateLabel,
}) {
  final buf = StringBuffer()
    ..writeln('🧾 Bills — $dateLabel')
    ..writeln();
  for (final bill in bills) {
    final name = shopMap[bill.order.shopId]?.name ?? 'Unknown';
    buf.writeln('🏪 $name — ${brand.money(bill.total)}');
  }
  buf.writeln();
  final grand = bills.fold<double>(0, (sum, bill) => sum + bill.total);
  buf.writeln('GRAND TOTAL: ${brand.money(grand)}');
  return buf.toString().trim();
}

/// One shop's bill, itemised.
String billDetailText({
  required String shopName,
  required OrderWithLines? order,
  required Map<int, Product> productMap,
  required BrandConfig brand,
  required String dateLabel,
}) {
  final buf = StringBuffer()
    ..writeln('🧾 Bill — $shopName')
    ..writeln('Date: $dateLabel')
    ..writeln();

  if (order == null || order.lines.isEmpty) {
    buf.writeln('No items');
    return buf.toString().trim();
  }

  final sorted = [...order.lines]..sort((a, b) {
      final na = productMap[a.productId]?.name.toLowerCase() ?? '';
      final nb = productMap[b.productId]?.name.toLowerCase() ?? '';
      return na.compareTo(nb);
    });

  var total = 0.0;
  for (final line in sorted) {
    final name = productMap[line.productId]?.name ?? 'Product #${line.productId}';
    final lineTotal = line.qty * line.unitPrice;
    total += lineTotal;
    buf.writeln('· $name × ${line.qty} — ${brand.money(lineTotal)}');
  }
  buf.writeln();
  buf.writeln('TOTAL: ${brand.money(total)}');
  return buf.toString().trim();
}
