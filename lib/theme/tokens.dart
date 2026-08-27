import 'package:flutter/material.dart';

/// The single source of truth for every colour, type step, spacing value,
/// corner radius and shadow in the app.
///
/// Before this file the app carried 14 distinct `fontSize:` literals, 111
/// ad-hoc `Colors.grey.shadeNNN` references, 8 corner radii and 117
/// `EdgeInsets` literals. Nothing outside `lib/theme/` may define those values
/// again — `tool/check_tokens.sh` is the ratchet that drives the remaining
/// sites down.
///
/// Brand colours (gold, espresso, dark roast, maroon) are *defaults* here and
/// resolve at runtime through `BrandConfig`; see `brand_config.dart`.

// ---------------------------------------------------------------------------
// Colour
// ---------------------------------------------------------------------------

abstract final class AppColors {
  // --- Brand (defaults — the live values come from BrandConfig) -------------

  /// Gold. Emphasis only: FAB, primary CTA, active chip fill, accents.
  /// Never carries meaning — a figure that is up is [positive], not gold.
  static const brandPrimary = Color(0xFFFFC000);

  /// Text and icons drawn on top of [brandPrimary].
  static const brandOnPrimary = Color(0xFF2B1A12);

  /// Espresso. Primary buttons, titles, active icons.
  static const brandDeep = Color(0xFF4A2C2A);

  /// Dark roast. Drawer ground, hero cards.
  static const brandDeepest = Color(0xFF3A2018);

  /// Maroon. Logo mark only — never a UI colour.
  static const brandMark = Color(0xFFB71C1C);

  // --- Surface --------------------------------------------------------------

  /// Cream page ground.
  static const bg = Color(0xFFFFFBF5);

  /// Cards and sheets.
  static const surface = Color(0xFFFFFFFF);

  /// Inset rows, table headers, disabled fills.
  static const surfaceMuted = Color(0xFFF7F1E8);

  /// Hairlines, card outlines, dividers.
  static const border = Color(0xFFEFE6DA);

  // --- Text (replaces all 111 ad-hoc greys) ---------------------------------

  static const textPrimary = Color(0xFF2B1A12);
  static const textSecondary = Color(0xFF7A6A5F);
  static const textTertiary = Color(0xFFA89A8E);
  static const textOnDark = Color(0xFFFFF7EC);

  // --- Semantic -------------------------------------------------------------
  //
  // Never decorative. If a row is red, something is wrong with it.

  static const positive = Color(0xFF1F9254);
  static const positiveSoft = Color(0xFFE6F4EC);
  static const negative = Color(0xFFD64545);
  static const negativeSoft = Color(0xFFFCEBEB);
  static const warning = Color(0xFFE8A33D);
  static const warningSoft = Color(0xFFFDF3E3);
  static const info = Color(0xFF6C5CE7);
  static const infoSoft = Color(0xFFEFEDFC);

  /// The "nothing is wrong, nothing is notable" tone that used to be drawn as
  /// `Colors.grey` at 111 sites.
  static const neutral = textSecondary;
  static const neutralSoft = surfaceMuted;
}

/// The meaning a badge, pill or banner carries. Pairs a foreground with its
/// soft fill so no call site picks the two independently.
enum AppTone {
  neutral(AppColors.neutral, AppColors.neutralSoft),
  positive(AppColors.positive, AppColors.positiveSoft),
  negative(AppColors.negative, AppColors.negativeSoft),
  warning(AppColors.warning, AppColors.warningSoft),
  info(AppColors.info, AppColors.infoSoft);

  const AppTone(this.fg, this.soft);

  final Color fg;
  final Color soft;
}

// ---------------------------------------------------------------------------
// Type
// ---------------------------------------------------------------------------

/// Eight steps, replacing fourteen ad-hoc font sizes.
///
/// These are also wired into `ThemeData.textTheme` by `app_theme.dart`, so
/// `Theme.of(context).textTheme` finally resolves to the design system.
/// `FontWeight.bold` is banned: weights come from a token or not at all.
///
/// **Every step carries `color: AppColors.textPrimary`, and must.** A
/// colourless `TextStyle` does not mean "inherit" once it reaches a theme
/// slot — Material widgets resolve their slot as
/// `widget.style ?? theme.slotStyle ?? defaults.slotStyle`, and only that
/// last term carries a colour. Supplying a colourless style at the theme
/// level therefore *displaces* the coloured default rather than merging with
/// it, and the engine's own fallback for an unset colour is white: invisible
/// on every surface in this app. That bug shipped three times here — AppBar
/// titles, dialog titles, then every `ListTile` on Profile — before the
/// colour moved onto the steps themselves.
///
/// Anything that needs a different colour still overrides it the usual way:
/// `AppType.body.copyWith(color: tone.fg)`.
abstract final class AppType {
  static const _family = 'Quicksand';

  /// 28 / w700 — hero figures. Theme slot: `displaySmall`.
  static const displayL = TextStyle(
    fontFamily: _family,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
    color: AppColors.textPrimary,
  );

  /// 22 / w700 — screen titles. Theme slot: `titleLarge`.
  static const titleL = TextStyle(
    fontFamily: _family,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  /// 17 / w600 — card titles, shop names. Theme slot: `titleMedium`.
  static const titleM = TextStyle(
    fontFamily: _family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  /// 15 / w600 — row titles. Theme slot: `titleSmall`.
  static const titleS = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  /// 14 / w500 — body text. Theme slot: `bodyMedium`.
  static const body = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  /// 13 / w500 — secondary rows, subtitles. Theme slot: `bodySmall`.
  static const bodyS = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  /// 12 / w600 — chips, buttons, table headers. Theme slot: `labelMedium`.
  static const label = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  /// 11 / w600, +0.8 tracking — section captions. Rendered uppercase by the
  /// components that use it. Theme slot: `labelSmall`.
  static const caption = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  /// Every Material `TextTheme` slot, filled from the eight steps above so no
  /// slot ever falls back to a Material default size.
  static const textTheme = TextTheme(
    displayLarge: displayL,
    displayMedium: displayL,
    displaySmall: displayL,
    headlineLarge: titleL,
    headlineMedium: titleL,
    headlineSmall: titleL,
    titleLarge: titleL,
    titleMedium: titleM,
    titleSmall: titleS,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: bodyS,
    labelLarge: label,
    labelMedium: label,
    labelSmall: caption,
  );
}

// ---------------------------------------------------------------------------
// Spacing, radius, elevation
// ---------------------------------------------------------------------------

/// Replaces 117 `EdgeInsets` literals.
abstract final class AppSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;

  /// Standard page gutter.
  static const page = EdgeInsets.symmetric(horizontal: s4);

  /// Standard card padding.
  static const card = EdgeInsets.all(s4);
}

/// Replaces 8 distinct `BorderRadius.circular(n)` values.
abstract final class AppRadius {
  /// 10 — chips, fields, small controls.
  static const rS = BorderRadius.all(Radius.circular(10));

  /// 16 — cards, sheets, inputs.
  static const rM = BorderRadius.all(Radius.circular(16));

  /// 24 — hero cards, bottom sheets.
  static const rL = BorderRadius.all(Radius.circular(24));

  /// Pills and avatars.
  static const rFull = BorderRadius.all(Radius.circular(999));
}

/// Two shadows, replacing scattered `withAlpha` guesswork. Material
/// `elevation:` is not used anywhere in the app.
abstract final class AppShadow {
  /// y2, blur 12, black 6%.
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 2)),
  ];

  /// y6, blur 20, black 10%.
  static const raised = <BoxShadow>[
    BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 6)),
  ];
}
