import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show Color;
import 'package:milano_orders/theme/brand_config.dart';
import 'package:milano_orders/utils/money.dart';

/// AGENTS.md rule 7: all money goes through `lib/utils/money.dart`.
///
/// The rule existed before this test and was broken at 23 sites across 17
/// files, every one of them writing a literal `₹` with Western grouping. On a
/// billing app for an Indian bakery that is not a style preference — the owner
/// hands these figures to shopkeepers.
void main() {
  const brand = BrandConfig.milano;

  group('Indian digit grouping', () {
    test('groups in lakhs, not thousands', () {
      // The whole point. Western grouping renders this 116,717.
      expect(brand.money(116717), '₹1,16,717');
      expect(brand.money(1234567), '₹12,34,567');
    });

    test('is unremarkable below a lakh', () {
      expect(brand.money(999), '₹999');
      expect(brand.money(24680), '₹24,680');
    });

    test('rounds rather than truncating', () {
      expect(brand.money(1499.6), '₹1,500');
    });
  });

  group('the decimal variants', () {
    test('moneyDecimal always shows two places, for columns that must align', () {
      expect(brand.moneyDecimal(116717), '₹1,16,717.00');
      expect(brand.moneyDecimal(12.5), '₹12.50');
    });

    test('moneyTrim drops trailing zeros', () {
      expect(brand.moneyTrim(12.50), '₹12.5');
      expect(brand.moneyTrim(12.00), '₹12');
      expect(brand.moneyTrim(12.34), '₹12.34');
    });
  });

  group('lakh abbreviation', () {
    // Replaces three byte-identical private copies in the dashboard cards.
    // These expectations are what those cards already rendered — the point of
    // centralising was to keep the display and lose the duplication.
    test('abbreviates at a lakh and not before', () {
      expect(brand.countLakh(99999), '99,999');
      expect(brand.countLakh(100000), '1.0L');
      expect(brand.countLakh(116717), '1.2L');
    });

    test('groups between a thousand and a lakh', () {
      expect(brand.countLakh(24680), '24,680');
    });

    test('stays plain under a thousand', () {
      expect(brand.countLakh(450), '450');
      expect(brand.countLakh(0), '0');
    });

    test('moneyLakh is countLakh with the brand symbol', () {
      expect(brand.moneyLakh(116717), '₹1.2L');
      expect(brand.moneyLakh(450), '₹450');
    });
  });

  group('symbol and locale come from the brand, never a literal', () {
    const other = BrandConfig(
      appName: 'Other Co',
      shortName: 'Other',
      tagline: 'x',
      logoAsset: 'x.png',
      primary: Color(0xFF000000),
      onPrimary: Color(0xFFFFFFFF),
      deep: Color(0xFF000000),
      deepest: Color(0xFF000000),
      mark: Color(0xFF000000),
      currencySymbol: r'$',
      locale: 'en_US',
    );

    test('a different brand changes both the symbol and the grouping', () {
      expect(other.money(116717), r'$116,717');
      expect(other.count(116717), '116,717');
    });
  });

  group('counts are grouped too', () {
    test('count has no symbol', () {
      expect(brand.count(116717), '1,16,717');
    });

    test('countTrim drops trailing zeros', () {
      expect(brand.countTrim(12.50), '12.5');
      expect(brand.countTrim(12.00), '12');
    });
  });
}
