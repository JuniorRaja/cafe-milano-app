# v2 Requirements — Phased Implementation Plan

## Context

`docs/v2-requirements.md` lists a batch of v2 improvements for the app (currently internally named "BakeOrder", Flutter/Dart, Drift+SQLite, Riverpod, go_router). Exploration confirmed:

- App name/branding ("BakeOrder") is hardcoded in `pubspec.yaml`, `lib/app.dart` (`MaterialApp.router` title), `lib/screens/home/home_screen.dart`, and `lib/screens/profile/profile_screen.dart`.
- `flutter_launcher_icons` is already configured (pointing at `mobile-app-logo-trasnsp.png`) but uses a gold adaptive-icon background — needs to become white.
- No splash screen package is configured; Android/iOS just show blank native launch backgrounds.
- `ProductQtyRow` only has +/- steppers, no direct numeric entry.
- Products (`lib/database/tables/products.dart`) have no `price` field at all — pricing today is 100% shop-specific via `ShopPrices` (`shopId`+`productId` → `price`). Without a shop price, `order_entry_screen.dart` shows "Price not set" and disables the steppers. This is what "two-way pricing" needs to fix: add a default price on `Product`, with `ShopPrices` continuing to override it.
- Unit is a free-text field in `product_form_screen.dart`.
- Profile screen has no version footer.
- `AppDatabase.schemaVersion` is `1` with no `onUpgrade` — relevant to the "doubt" question and to the price-column addition, which must be a proper migration.

Decisions confirmed with the user:
- App name: **"Milano Orders"**.
- Splash: native launch shows the logo only (instant, no animation); once Flutter loads, a brief in-app screen fades/scales the logo in (~1–1.5s), then navigates to Home. The time-based greeting is **not** a separate splash screen — it's inserted directly into the Home screen, between the app bar and the existing `DateSelector` row.
- Quantity entry: tapping the quantity number opens a modal with a numeric text field plus +/- buttons.
- Unit dropdown defaults: `pc, kg, g, dozen, box, packet, litre, ml` + `Other` (reveals free-text entry).

---

## Phase 0 — Rebrand to "Milano Orders"

**Action items:**
- [ ] `pubspec.yaml`: update `name`/`description`.
- [ ] `lib/app.dart`: `MaterialApp.router(title: ...)`.
- [ ] `lib/screens/home/home_screen.dart` and `lib/screens/profile/profile_screen.dart`: replace the "Bake"/"Order" two-tone `RichText` with "Milano" (accent color) / "Orders", update subtitle copy.
- [ ] `pubspec.yaml` `flutter_launcher_icons`: change `adaptive_icon_background` from `"#FFC000"` to `"#FFFFFF"`, then regenerate icons (`flutter pub run flutter_launcher_icons`). Android/iOS both auto-mask adaptive icons to rounded shapes already, so no extra rounding work is needed beyond the background color and regeneration.

**Success criteria:**
- [ ] App bar, window title, and Profile header all read "Milano Orders" consistently.
- [ ] Regenerated launcher icon shows the logo on a white background, correctly rounded on an emulator/device home screen.

## Phase 1 — Splash Screen + Home Greeting ✅ Done

**Action items:**
- [x] Add `flutter_native_splash` dev dependency; configure a plain white-background + logo native splash for Android/iOS, generate via its CLI.
- [x] New `lib/screens/splash/splash_screen.dart`: a `StatefulWidget` that fades/scales the logo in over ~1.2s using an `AnimationController`, then `context.go`/replaces route to Home. Wire it as the initial go_router route.
- [x] Update `lib/main.dart` to call `FlutterNativeSplash.preserve`/`.remove()` around this so there's no blank frame between native and in-app splash.
- [x] `lib/screens/home/home_screen.dart`: insert a `Text` between the `AppBar` and `const DateSelector()` showing a time-based greeting, computed inline from `DateTime.now().hour` (morning/afternoon/evening bands) — plain function, no new provider needed. Ended up styled as a two-line hero block (time-of-day icon + "Good <time>, <name>", name picked randomly once per app launch from Mohan/JMR) rather than a plain text line.

**Success criteria:**
- [x] Cold launch shows the logo instantly (no white flash).
- [x] A brief fade/scale animation plays (~1–1.5s) before Home appears.
- [x] Home shows the correct time-based greeting rendered between the app bar and the date selector row.

## Phase 2 — Tap-to-Edit Quantity Modal ✅ Done

**Action items:**
- [x] `lib/widgets/product_qty_row.dart`: wrap the quantity `Text` in a `GestureDetector`, add an `onQtySet(int)` callback prop.
- [x] Tapping opens a modal (`showModalBottomSheet` or `showDialog`) containing a numeric `TextField` pre-filled with the current qty plus +/- buttons for quick nudges, and a confirm action.
- [x] `lib/screens/order_entry/order_entry_screen.dart`: pass `onQtySet: (v) => _setQty(product.id, v.clamp(0, 9999))` alongside the existing `onIncrement`/`onDecrement`.

**Success criteria:**
- [x] Tapping the qty number opens a modal with a numeric-keyboard input pre-filled with the current value and +/- controls.
- [x] Confirming updates the order line exactly as the existing steppers do.
- [x] Canceling leaves the quantity unchanged.

## Phase 3 — Two-Way Pricing (Default Price + Shop Override) ✅ Done

**Action items:**
- [x] `lib/database/tables/products.dart`: add `RealColumn get price => real().nullable()()`.
- [x] `lib/database/app_database.dart`: bump `schemaVersion` to `2`, add a `MigrationStrategy` with `onUpgrade` that does `m.addColumn(products, products.price)` for the 1→2 step.
- [x] `lib/screens/profile/products/product_form_screen.dart`: add a "Price" numeric `TextFormField`, load/save it via `ProductsCompanion.price`.
- [x] `lib/screens/order_entry/order_entry_screen.dart`: change price resolution from `_priceMap[p.id]` to `_priceMap[p.id] ?? product.price`, so shop-specific price wins when set, otherwise the product's default price is used; "Price not set" / disabled steppers remain only for products with neither.
- [x] `lib/database/seed_data.dart`: add sample default prices to seeded products for consistent demo data. Also trimmed the seed down to 2 shops (Hotel Raj, Star Bakery); Hotel Raj overrides every product's price, Star Bakery only overrides Bun and Bread so the rest demonstrate the default-price fallback.

**Success criteria:**
- [x] A product with only a default price is orderable (priced) in every shop.
- [x] Setting a shop-specific price in Price Matrix overrides the default for that shop only.
- [x] Upgrading an existing install (schema v1 → v2) preserves all existing shops/orders/prices with no data loss.

## Phase 4 — Unit Dropdown ✅ Done

**Action items:**
- [x] `lib/screens/profile/products/product_form_screen.dart`: replace the Unit `TextFormField` with a `DropdownButtonFormField<String>` listing `pc, kg, g, dozen, box, packet, litre, ml, Other`.
- [x] Selecting "Other" reveals the existing `_unitCtrl` text field for custom entry.
- [x] On load, if a product's saved unit isn't in the default list, preselect "Other" and populate the custom field with it (keeps existing free-text units working).

**Success criteria:**
- [x] Product form offers a unit dropdown with the agreed defaults.
- [x] Choosing "Other" reveals free-text entry.
- [x] Products with pre-existing custom units still load/display/save correctly.

## Phase 5 — Version Footer on Profile ✅ Done

**Action items:**
- [x] Add `package_info_plus` dependency to read the real runtime version/build number (avoids hardcoding, stays in sync with `pubspec.yaml`).
- [x] `lib/screens/profile/profile_screen.dart`: add a footer block at the bottom of the `ListView` — large, low-opacity "CAFE MILANO" wordmark-style text, with `vX.Y.Z (build N)` beneath it, centered.

**Success criteria:**
- [x] Bottom of Profile screen shows the faded "CAFE MILANO" block with the correct live app version beneath it, matching `pubspec.yaml`.

---

## FAQ: What happens to local data when installing a newer APK?

Android preserves app-private storage (including the SQLite file under the app's documents directory, where Drift keeps `bakeorder.db`) across an **update** install, provided:
- the package/application ID doesn't change,
- the new APK is signed with the same key as the currently-installed one (enforced by Play Store; must match manually for sideloaded builds too),
- it's an update, not an uninstall-then-reinstall, and the user hasn't manually cleared app data.

If any of those differ, Android either blocks the install or forces an uninstall first, which wipes local data.

The other real risk is **schema drift**: Drift will throw at runtime if the compiled `schemaVersion` doesn't match what's on disk and there's no migration path registered. That's exactly why Phase 3 bumps `schemaVersion` and adds an explicit `onUpgrade` step — without it, adding the `price` column would break existing installs on update. Going forward, every schema change should bump the version and add an explicit migration step.

---

## Verification

- [ ] `flutter analyze` passes after each phase.
- [ ] `flutter run` on an emulator/device to visually confirm: new icon + splash + greeting (Phase 0/1), qty modal behavior (Phase 2), price fallback behavior across Price Matrix vs. default price (Phase 3), unit dropdown incl. legacy custom units (Phase 4), profile version footer (Phase 5).
- [ ] Migration check for Phase 3: build and install the current `schemaVersion 1` app, create a shop/product/order, then install the new build over it (not uninstall) and confirm existing data is intact and prices behave per the new fallback logic.
