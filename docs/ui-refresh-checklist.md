# UI Refresh Checklist

Source discussion: logo-matched color palette, spacing/density, and micro-interactions.
Each section is independent — implement one at a time, in any order.

---

## 1. Color Palette

Problem: `kBrandCrimson` (`app.dart:17`) is used as the seed for the whole Material3
`ColorScheme.fromSeed()`, so it drives buttons/FAB/selected states *and* reads as
error-red (35 usages across 14 files, all from the one seed).

New palette:

| Role | Color | Hex |
|---|---|---|
| Primary (seed) | Bakery Gold | `#F0A202` |
| Secondary / dark accent | Espresso Brown | `#4A2C2A` |
| Brand accent (sparing, non-seeded) | Logo Maroon | `#B71C1C` |
| Surface | Warm cream | `#FFFBF5` (unchanged) |
| Text (ink) | Charcoal | `#2B2320` |
| Error / destructive only | Material red 700 | `#C62828` |

- [x] Update constants in `lib/app.dart`: `kBrandGold` (unchanged, `#FFC000`, now primary seed), new `kBrandBrown` (`#4A2C2A`, active/selected/icon accents), `kBrandMaroon` (renamed from `kBrandCrimson`, `#B71C1C`, kept defined but unused — reserved for a future genuine brand-mark spot, not seeded), `kSurface` unchanged
- [x] Change `ColorScheme.fromSeed(seedColor: ...)` to use gold instead of crimson
- [x] Replace direct `kBrandCrimson` usages (selected nav icon/label, tab bar indicator/label, avatars, chips, totals, icons) with `kBrandBrown` — audited actual usages (10 files, not the originally-guessed 14; `shop_form_screen.dart`, `product_form_screen.dart`, `standing_orders_screen.dart`, `date_selector.dart` had no direct references and inherit the new seed automatically):
  - [x] `lib/app.dart`
  - [x] `lib/screens/profile/prices/price_matrix_screen.dart`
  - [x] `lib/screens/profile/profile_screen.dart`
  - [x] `lib/screens/order_entry/order_entry_screen.dart`
  - [x] `lib/screens/kitchen/kitchen_screen.dart`
  - [x] `lib/screens/orders/orders_screen.dart`
  - [x] `lib/screens/home/home_screen.dart`
  - [x] `lib/widgets/product_qty_row.dart`
  - [x] `lib/widgets/shop_order_card.dart`
  - [x] `lib/widgets/letter_avatar.dart`
- [x] Found and fixed two spots using literal `#FFEBEE` (Material red-50) as a chip/icon background behind crimson — replaced with `kBrandGold.withAlpha(40)` (`shop_order_card.dart` `_BrandChip`, `profile_screen.dart` menu icon tile) — these were the strongest "danger" cues since they mimicked Material's own error-chip styling
- [x] Confirm Order button (`order_entry_screen.dart:479`) changed from crimson-bg/white-text to gold-bg/black87-text to match the app's existing CTA convention (FAB)
- [x] Reserve `Colors.red`/error colors strictly for delete/cancel actions — none were touched, no accidental use found
- [x] Reserve logo maroon (`#B71C1C`) for a genuine brand-mark spot only — kept as an unused constant for now since no splash/brand-mark surface exists yet; not seeded into interactive scheme
- [x] `adaptive_icon_background` in `pubspec.yaml` — left as `#FFC000`, unchanged since gold hex didn't change
- [ ] Visual pass on all 4 tabs + order entry + forms on a device/emulator to confirm no red/danger ambiguity remains (code-level change verified via `flutter analyze`, no UI run yet)

## 2. Density / Spacing

Problem: padding values in code are standard (mostly 16px/8px) — the "spacious" feel
is likely Material 3 defaults (NavigationBar 80dp height, default ListTile/Card
insets, default visualDensity), not display DPI.

- [ ] Add `visualDensity: VisualDensity.compact` (or custom `(-1,-1)`) to `ThemeData` in `lib/app.dart`
- [ ] Reduce `NavigationBar` height/insets in `_ScaffoldWithNavBar`
- [ ] Tighten `Card` margins where used (check `shop_order_card.dart` and list screens)
- [ ] Tighten default `ListTile` content padding where used
- [ ] Re-check `orders_screen.dart` and `home_screen.dart` layouts after density change for overflow/clipping
- [ ] Compare before/after on a real device or emulator at your normal DPI setting

## 3. Micro-interactions

No new dependencies — built-in Flutter implicit animations only.

- [ ] Quantity steppers (`product_qty_row.dart`): tap scale-bounce + `HapticFeedback.lightImpact()`
- [ ] Add-to-order action: brief checkmark/scale confirmation instead of static snackbar
- [ ] Tab switches (`_ScaffoldWithNavBar` in `app.dart`): `AnimatedSwitcher` fade/slide between shell branches
- [ ] Order cards (`shop_order_card.dart`): `AnimatedContainer` for selected/expanded state, elevation change on press
- [ ] FAB: icon morph/rotate when context changes (e.g. order entry vs. list)
- [ ] Pull-to-refresh: custom indicator color matching new gold palette
- [ ] List entrance: light staggered fade-in for order/kitchen list items on load
- [ ] Verify animations respect reduced-motion / don't jank on lower-end devices
