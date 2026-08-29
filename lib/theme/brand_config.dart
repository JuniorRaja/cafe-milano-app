import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tokens.dart';

/// Everything about the app that is *this business* rather than *this product*.
///
/// White-labelling itself is doc 17; this is only the seam it will need. It
/// ships now because adding it at token-definition time costs almost nothing,
/// and retrofitting it would mean touching every screen a second time.
///
/// One rule, and it is absolute: **no UI string may contain "Milano", "Cafe
/// Milano" or "bakery".** Everything brand-shaped resolves through
/// [brandProvider].
///
/// Business-domain wording — "shop", "kitchen" — stays hardcoded. Making
/// *terminology* configurable is doc 17's problem.
@immutable
class BrandConfig {
  const BrandConfig({
    required this.appName,
    required this.shortName,
    required this.tagline,
    required this.logoAsset,
    required this.primary,
    required this.onPrimary,
    required this.deep,
    required this.deepest,
    required this.mark,
    required this.currencySymbol,
    required this.locale,
  });

  /// Window/app title and the drawer header. e.g. `Milano Orders`.
  final String appName;

  /// The wordmark's first half, drawn in [deep] beside `appName`'s remainder.
  final String shortName;

  /// One line under the wordmark. e.g. `Daily Order Manager`.
  final String tagline;

  final String logoAsset;

  final Color primary;
  final Color onPrimary;
  final Color deep;
  final Color deepest;

  /// Logo mark only — never a UI colour.
  final Color mark;

  final String currencySymbol;

  /// Locale tag used for number grouping. `en_IN` groups as `1,16,717`, which
  /// is a real formatting difference and not just a symbol swap.
  final String locale;

  /// The remainder of [appName] after [shortName], used by the wordmark so the
  /// two halves can be drawn in different colours without hardcoding either.
  String get appNameRest =>
      appName.startsWith(shortName) ? appName.substring(shortName.length) : '';

  static const milano = BrandConfig(
    appName: 'Milano Orders',
    shortName: 'Milano',
    tagline: 'Daily Order Manager',
    logoAsset: 'mobile-app-logo-trasnsp.png',
    primary: AppColors.brandPrimary,
    onPrimary: AppColors.brandOnPrimary,
    deep: AppColors.brandDeep,
    deepest: AppColors.brandDeepest,
    mark: AppColors.brandMark,
    currencySymbol: '₹',
    locale: 'en_IN',
  );
}

/// App-lifetime by design: the brand never changes within a run. Deliberately
/// not `autoDispose`.
final brandProvider = Provider<BrandConfig>((ref) => BrandConfig.milano);
