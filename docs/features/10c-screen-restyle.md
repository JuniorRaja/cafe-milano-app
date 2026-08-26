# 10c — Screen restyle

| | |
|---|---|
| **Target version** | `1.8.1+12` |
| **Type** | Foundation (patch — restyle, no new capability) |
| **Schema** | No change |
| **Requires** | [10a — Design system](10a-design-system.md), [10b — Navigation](10b-navigation.md) |
| **Part of** | [10 — UI overhaul](10-ui-overhaul.md) |
| **Status** | Ready |

## Why

[10a](10a-design-system.md) ships the component kit **deliberately unused** — a
foundation release whose diff also rewrites twenty screens cannot be reviewed or
reverted. [10b](10b-navigation.md) rearranges where screens live without touching what
is inside them. This is the release that actually rebuilds the screens on the kit.

It is also the release that closes the ratchet. After 10a the app still contains 111
ad-hoc greys, 14 font sizes, 117 spacing literals and a pile of `@Deprecated`
`kBrandGold` imports. `tool/check_tokens.sh` reports those counts and fails; **this
release drives them to zero and flips the script to blocking in CI.** If that does not
happen here it does not happen, and the app drifts back within three releases.

**Every remaining screen is migrated, including ones that pending docs will extend.**
That is the point of the sequencing decision: docs [06](06-ledger-manual-allocation.md)–
[12](12-dashboard-tabs.md) then build their features onto already-migrated screens, and
no screen is built twice.

**Explicitly out of scope:** any behaviour change, any new screen, any new query. If a
number on screen changes, that is a bug — this is a restyle.

## What "restyled" means

Not "made prettier". Each screen gets the same four things, and they come from the
reference screens:

1. **`AppScaffold`** — one header idiom, replacing the 5 hand-rolled headers and the 15
   `AppBar`s.
2. **A summary band before the list, where the screen has a headline number.** Reference
   image 2's `16/18 shops · ₹24,680 ↑8%`. Today the billing screen computes its grand
   total with `summaries.fold` and then renders it *below the fold* — you scroll to find
   the number the screen exists to tell you.
3. **Dense scannable rows.** Reference image 3's at-risk row is an avatar, a name, an
   area, a right-aligned amount and a red age line. `ShopOrderCard` spends a full
   16-padded card, an avatar, a title, an area row and a chip row to say "Tap to add
   order". Same information, roughly half the height, and money forms a straight
   right-hand column — the principle commit `762be58` already established for the
   ledger.
4. **Empty states with an action.** Six screens currently render a grey icon at size 64
   and one line of grey text. An empty shop list should offer "Add your first shop".

## Action items

### Daily screens

- [ ] **Home** (`home_shops_screen.dart`) — `AppScaffold`; a `StatBand` reading
      `N ordered · M pending · ₹X today`; a `FilterChipRow` of
      `All 18 · Ordered 14 · Pending 4` with live counts; `ShopOrderCard` replaced by
      `ListRow`. This is the screen that answers "which shops still need an order
      today", and today you answer it by scrolling.
- [ ] **Billing** (`orders_screen.dart`) — `AppScaffold`; **grand total moves into a
      `StatBand` above the list**; expandable rows rebuilt on `AppCard` + `MiniTable`.
      Keep `_expandedOrderId` behaviour exactly as it is.
- [ ] **Kitchen** (`kitchen_screen.dart`) — `AppScaffold` with the existing two tabs in
      its `bottom` slot; a `StatBand` of total items · total quantity; category emoji
      rows on `ListRow`. The share action moves into `AppScaffold.actions`.
- [ ] **Order entry** (`order_entry_screen.dart`) — see below. This one is not just a
      restyle.

### Order entry — the rebuild fix

Every quantity tap calls `setState`, rebuilding **all 28 product rows to change one
number**, then debouncing a 500 ms full `replaceOrderLines`. It is the most-used screen
in the app, used at 5 a.m. under time pressure, and
[doc 08](08-order-entry-swipe.md) is about to add a swipe gesture to it — which makes
the per-tap cost matter considerably more than it does today.

**This must land before doc 08.** Doc 08 should not be built on a screen that rebuilds
28 rows per gesture frame.

- [ ] Hold quantities in a `ValueNotifier<int>` per row (or a scoped family provider) so
      a tap rebuilds **one** row. Keep the 500 ms debounce and the existing save path
      unchanged — the write is fine, the rebuild is not.
- [ ] The screen currently bypasses the provider layer entirely
      (`ref.read(databaseProvider)` plus `.first` on four streams). Leave that as is.
      Converting it to providers is a real change to a screen that carries orders, and
      it belongs in [doc 14](14-supabase-auth.md)'s port, not in a restyle.
- [ ] Sticky total bar at the bottom: item count and running ₹ total, live as you type.
- [ ] `AppScaffold` header showing shop name and the order's date.

### Masters

All reachable from [10b](10b-navigation.md)'s CATALOGUE group.

- [ ] `shop_list_screen.dart` — `ListRow` with the outstanding figure from 10b's
      `watchOutstandingByShop`; keep "Owes" mode; search when the list exceeds 20.
- [ ] `product_list_screen.dart` — `ListRow` grouped by category, category emoji
      leading, price trailing. Keep the share action where it is.
- [ ] `category_list_screen.dart` — `ListRow` with a live product count per category,
      as reference image 1 shows ("Puffs · 45 products").
- [ ] `shop_form_screen.dart`, `product_form_screen.dart`,
      `business_info_form_screen.dart` — rebuilt on the kit's inputs, matching reference
      image 1's form: field label above a `rM`-radius bordered input, required markers,
      a full-width dark-brown primary button pinned at the bottom.
- [ ] `standing_orders_screen.dart`, `catalog_share_picker_screen.dart`,
      `backup_restore_screen.dart`, `dashboard_settings_screen.dart`,
      `kpi_help_screen.dart` — `AppScaffold` and kit components. No layout invention;
      these work, they just look like five different apps.
- [ ] **`price_matrix_screen.dart`** — the one with a real problem. It renders up to
      504 cells (18 shops × 28 products) from an eager `ListView(`. Convert to
      `ListView.builder`, add a sticky product column, and show unset prices in
      `warning` rather than as blanks. "212 of 504 prices set" is
      [10b](10b-navigation.md)'s settings summary for this screen; the screen itself
      should say the same thing in its `StatBand`.

### Dashboard and ledger

Migrated here so docs [12](12-dashboard-tabs.md) and
[06](06-ledger-manual-allocation.md)/[07](07-ledger-statements.md) extend a
current-generation screen rather than restyling one.

- [ ] The 7 dashboard cards move onto `AppCard`; `PulseCard` becomes a `HeroStatCard`
      per reference image 3; every delta becomes a `DeltaPill` with **semantic** colour
      instead of raw `Colors.green` / `Colors.red`. **No tabs** — that is
      [doc 12](12-dashboard-tabs.md), and doing it here would collide.
- [ ] `dashboard_screen.dart` — replace the hand-written 14-provider
      `_refreshDashboard` with a single refresh family. Any provider added later and not
      added to that list silently stops refreshing today.
- [ ] `shop_ledger_screen.dart` and `record_payment_sheet.dart` onto the kit.
      **Preserve every decision commit `762be58` and `dc8ce8d` recorded**: no trailing
      delete icon, status badge beside the date, filters behind a sheet, money in a
      straight right-hand column. Those were learned from real use — re-deriving them
      from a mockup would be a regression.

### Closing the ratchet

- [ ] Delete `kBrandGold`, `kBrandBrown`, `kBrandMaroon`, `kSurface` and
      `kDefaultLogoAsset` from `lib/app.dart`. They are `@Deprecated` aliases from
      [10a](10a-design-system.md) and 60+ files import them; this release empties the
      last one.
- [ ] `tool/check_tokens.sh` → **blocking** in CI.
- [ ] `flutter analyze` clean, including zero deprecation warnings.

### Tests

- [ ] `test/widget_test.dart` — extend to cover the migrated screens building and
      rendering their headline figures.
- [ ] **No new arithmetic tests.** Nothing here changes a calculation. If a restyle
      needs a new money test, the restyle has changed behaviour and is wrong.

## Success criteria

- [ ] `grep -rn "Colors\.grey" lib/screens lib/widgets` → **0** outside
      `lib/widgets/ui/`, down from 111.
- [ ] No `fontSize:` literal in `lib/screens/` — down from 14 distinct values.
- [ ] No `BorderRadius.circular(` outside `lib/widgets/ui/` — down from 8 distinct
      values.
- [ ] `tool/check_tokens.sh` passes and is blocking.
- [ ] `flutter analyze` reports zero warnings, deprecations included.
- [ ] Every screen uses `AppScaffold`. **Zero** hand-rolled headers, **zero** bare
      `AppBar`s — down from 5 and 15.
- [ ] The billing grand total is visible **without scrolling** on an 18-shop day.
- [ ] The home list shows at least **8 shops** in one viewport on the owner's device,
      up from 4–5.
- [ ] A quantity tap on order entry rebuilds **one** row. Verified with the DevTools
      rebuild counter, not by feel.
- [ ] Order entry holds 60 fps while a quantity is held down.
- [ ] Price matrix opens in under 400 ms with all 18 shops and 28 products loaded.
- [ ] All six empty states offer an action.
- [ ] **Every figure on every screen matches `1.8.0` on the same dataset.** This is a
      restyle; any changed number is a bug.
- [ ] Every ledger decision from `762be58` and `dc8ce8d` survives — checked against
      those commits explicitly.

## Notes

- **This is the movable part of the block.** Nothing depends on it, so it can slide
  behind [06](06-ledger-manual-allocation.md) and [07](07-ledger-statements.md) if
  feature work is more urgent. It must **not** slide behind
  [08](08-order-entry-swipe.md), which adds a swipe gesture to the order-entry screen
  whose per-tap rebuild this release fixes.
- **The ratchet is the reason this release is not optional.** Tokens that only half the
  app uses are worse than no tokens, because the next person cannot tell which half is
  correct.
