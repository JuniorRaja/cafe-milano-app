import 'package:intl/intl.dart';

import '../theme/brand_config.dart';

/// The one place money is turned into text.
///
/// Replaces ~30 call sites that each wrote `'₹${NumberFormat('#,##0')
/// .format(v)}'` by hand with a literal rupee sign and Western digit grouping.
/// Both the symbol and the grouping come from [BrandConfig] — Indian grouping
/// (`1,16,717`) is a real formatting difference, not a symbol swap.
///
/// Usage: `ref.watch(brandProvider).money(total)`.
extension MoneyFormat on BrandConfig {
  /// `₹1,16,717` — whole rupees. The default for every headline and total.
  String money(num value) => '$currencySymbol${count(value)}';

  /// `₹1,16,717.25` — fixed decimals. For statements and per-unit prices that
  /// must line up in a column.
  String moneyDecimal(num value, {int decimals = 2}) =>
      '$currencySymbol${_format(decimals).format(value)}';

  /// `₹12.50` → `₹12.5`, `₹12.00` → `₹12` — up to two decimals, trailing
  /// zeros dropped. Replaces the `#,##0.##` idiom.
  String moneyTrim(num value) => '$currencySymbol${countTrim(value)}';

  /// `₹1.2L` — for chart axes and leaderboards where the exact figure is not
  /// the point.
  String moneyCompact(num value) =>
      '$currencySymbol${NumberFormat.compact(locale: locale).format(value)}';

  /// Grouped number without the currency symbol — piece counts, quantities.
  String count(num value) => _format(0).format(value);

  /// Grouped number, up to two decimals, trailing zeros dropped, no symbol.
  String countTrim(num value) {
    final f = _format(2);
    final text = f.format(value);
    final sep = f.symbols.DECIMAL_SEP;
    if (!text.contains(sep)) return text;
    return text
        .replaceFirst(RegExp('0+\$'), '')
        .replaceFirst(RegExp('${RegExp.escape(sep)}\$'), '');
  }

  NumberFormat _format(int decimals) => NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: decimals,
  );
}
