# 10c — Screen restyle

| | |
|---|---|
| **Target version** | `1.12.0+16` |
| **Type** | Foundation (minor — every screen looks different afterwards) |
| **Schema** | No change |
| **Requires** | [10a — Design system](10a-design-system.md) · [18 — Guardrails](18-foundation-guardrails.md) · [10b — Navigation](10b-navigation.md) |
| **Absorbs** | Lifecycle audit **Phases 2, 3** and the remainder of **6** |
| **Part of** | [10 — UI overhaul](10-ui-overhaul.md) |
| **Status** | **Shipped — `1.12.0+16`, 2026-09-06** |

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

> **Amended 2026-09-06, on the owner's device pass.** One figure changes on
> purpose. An order entered against a future date — a shop ordering on Friday
> for Sunday — counted as receivable immediately, so the ledger claimed money
> for goods not yet delivered and put the shop in the at-risk list for an
> order it had not received. Receivables now stop at today.
>
> That is a deliberate, requested departure from the rule above, and it means
> the *"every figure matches `1.8.0`"* criterion below **cannot** hold for a
> shop with a future-dated order. Everything else still must.

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
5. **A real error state.** `AppErrorView` — message, cause, retry — from
   [18](18-foundation-guardrails.md)'s kit addition. See below.

## Absorbed lifecycle phases

Three phases of [`docs/flutter-lifecycle-audit.md`](../flutter-lifecycle-audit.md) land
here, because all three are edits to the same twenty screens this release is already
rewriting. Doing them separately means opening every screen twice.

### Phase 3 — `AsyncValue` discipline

This is the one with a defect behind it. **A database failure on the Kitchen screen
currently renders as "No orders for this date."** The operator is told there is nothing to
bake.

- [ ] **Delete every error-swallowing `maybeWhen(orElse:)`.** Twelve sites. Where a screen
      needs several providers, compose them into one derived provider returning a record,
      and let the screen `.when` on a single `AsyncValue` — one loading state, one error
      state, one data state, instead of four independent `maybeWhen`s in a build method.
- [ ] **Replace all sixteen `error: (e, _) => Text('Error: $e')` sites** with
      `AppErrorView`. Raw `toString()` on screen with no retry is not an error state.
- [ ] **Log before rendering.** Every error branch reports to
      [10b](10b-navigation.md)'s `ProviderObserver`. Stack traces stop being discarded
      via `(e, _)`.
- [ ] `attention_flags.dart` renders a failed state instead of vanishing.
- [ ] **"Empty" and "failed" must be visually distinct on every screen.** That is the
      actual fix; the widgets are just how it gets there.

### Phase 2 — the remaining defects

[18](18-foundation-guardrails.md) already shipped the three-line debounce flush as an
emergency stop. This is the correct version, plus the rest of the phase.

- [ ] **`OrderDraftController`** — a `Notifier` owning the debounce timer and exposing
      `flush()`, called from `dispose`, from the `AppLifecycleListener`'s `paused`, and
      from confirm. 18's test carries over unchanged and must still pass.
- [ ] **Get DB writes out of `setState`.** The `setConfirmed` calls at
      `order_entry_screen.dart:110` and `:228` move into the controller, awaited, with the
      local flag updated *after* the write succeeds and an error surfaced if it does not.
      18's `discarded_futures` lint will not let this regress.
- [ ] **Give `_init` a failure path** — or better, replace `_init` plus six `State` fields
      with one `AsyncNotifier` whose `AsyncError` the screen renders.
- [ ] **Apply the existing correct pattern to `record_payment_sheet._save`.** `try`/`catch`
      into a SnackBar, `finally` clear `_saving` behind a `mounted` guard. Copy
      `shop_ledger_screen.dart:126-153` verbatim; it is already right.
- [ ] Sweep the remaining ~19 unguarded UI-initiated DB calls with the same shape.

### Phase 6 — what 10a left

- [ ] **Migrate the 96 global colour reads** to theme reads, file by file. The 32
      `import '../../app.dart'` lines disappear with them. **These reads _are_ the
      `@Deprecated` alias warnings** — driving the analyzer count from 84 to zero and
      finishing this item are the same task.
- [x] **`_router` becomes `routerProvider`.** Landed with 10b's shell rewrite;
      `app.dart:304`. `widget_test.dart` and `navigation_test.dart`
      each hand-maintain a parallel route table today; they override the real one instead.
      That also means `navigation_test.dart`'s duplicate-page-key rule is finally tested
      against the actual router.

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
[doc 08](08-order-entry-swipe.md) has already added a long-press repeat that fires
every 400 ms — shipped 2026-08-27, ahead of this restyle block, on direct request.

**This was meant to land before doc 08; it didn't.** The rebuild now happens live in
production roughly two and a half times a second while a stepper is held, not just
hypothetically. See [roadmap.md](../roadmap.md) for the reordering. Land this next —
it is no longer preventive, it is a fix for something already shipped.

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
- [x] **Every figure on every screen matches `1.8.0` on the same dataset** —
      *except* receivables for a shop with a future-dated order, which changed
      on purpose. See the amendment at the top.
- [ ] Every ledger decision from `762be58` and `dc8ce8d` survives — checked against
      those commits explicitly.

## Progress

Branch `release/1.12.0-screen-restyle`, cut from `1.11.0+15`.
**Shipped 2026-09-06.** Built, then walked on the phone by the owner, whose
findings are the last two commits.

Much of the action list above was overtaken by
[10b's device pass](10b-device-pass.md), which rebuilt eight screens from the
phone rather than from a mockup. Those are marked *device pass*.

| Item | Landed |
|---|---|
| Home, Kitchen, Billing, Ledger, Masters, price matrix | device pass |
| Phase 6 · `routerProvider` | 10b |
| `AppScaffold` on the nine Settings + KPI screens | `c333ac6` |
| Phase 3 · error handling, all 19 + 12 sites | `31bfce6` |
| Phase 2 · order-entry rebuild and awaited writes | `1e611f8` |
| Greys and radii onto the tokens | `fb667b8` |
| Ratchet to zero, aliases deleted, gate blocking | `649a24d` |
| The last `AppBar`, and a refresh list that cannot go stale | `82cae1e` |
| Home's `StatBand` and `FilterChipRow` | `92acb63` |
| The dashboard cards onto the kit | `692a41d` |
| The three forms — `AppField` and a pinned Save | `eee9d47` |

### The ratchet

```
Colors.grey            139 -> 0
fontSize: literals     198 -> 0
BorderRadius.circular   59 -> 0
---
total                  396 -> 0    SCREENS_BLOCKING=1
```

`flutter analyze` reports **No issues found** — not "zero errors and warnings
with 48 deprecation infos", which is how every release since 10a reported.
The five `@Deprecated` aliases are deleted from `lib/app.dart`.

`flutter test`: **338 passing**, from 336.

### The device pass

Walked by the owner on 2026-09-06. Seven findings, all fixed:

| Finding | Fix |
|---|---|
| Category scorecards drew as empty space | `7334cef` — the AppCard conversion stripped `width: 160` from cards that scroll *horizontally*, so they collapsed |
| Revenue mix overflowed on the right | `7334cef` — `DeltaPill` does not fit a 44px column; reverted to the arrow |
| The Pulse card's new design | `7334cef` — reverted to its 2×2 grid |
| The `confirmed · pending · today` band on Orders | `7334cef` — removed; the chips below already carry the counts |
| Attention-flags card inset from its neighbours | `6c1aa54` — it paid the page gutter twice |
| Scorecard charts blank when the period changed | `e38aca6` — the sparkline was hardwired to the last 7 days while the numbers followed the period |
| Future-dated orders counted as receivable | `e38aca6` — receivables now stop at today |

The owner confirmed the build reads correctly after these. The performance
numbers (60 fps on a held stepper, 8 shops per viewport, price matrix under
400 ms) were judged by eye rather than instrumented; if any of them is ever in
doubt, the DevTools rebuild counter is the tool the original criteria named.

### Deliberately not done

- **The price matrix `StatBand`.** Built and reverted: watching
  `catalogueCoverageProvider` there adds a third drift stream to that screen
  and hangs `masters_editors_test` on the QueryStream teardown timer this repo
  has hit before. The figure is already on the Settings row that opens the
  screen, from 10b, so nothing is missing except the repetition. Worth a
  retry with a one-shot read.
- **The `OrderDraftController` / `AsyncNotifier` rewrite.** `flush()` already
  exists, is registered with `pendingWritesProvider`, and is called from
  `dispose` and from the lifecycle `paused` hook; [18](18-foundation-guardrails.md)'s
  test passes unchanged. Moving working code into a Notifier is a relocation,
  not a fix.
- **The price matrix sticky product column.** The screen is one shop at a
  time, so there is no second axis to pin — the doc's 18x28 grid is not what
  the screen renders.

### Corrections to this doc, found while building

- **Phase 6 overstates the import removal.** `AppRoutes` also lives in
  `lib/app.dart`, so a screen that navigates keeps `import '../../app.dart'`
  after its colour reads are gone. 13 imports left, not 32.
- **The forms needed a label widget, not a border fix.**
  `inputDecorationTheme` already carried `AppRadius.rM`; the per-field
  `border: OutlineInputBorder()` overrides were defeating it. But
  *label-above-input* is a layout the theme cannot express, so `AppField`
  joined the kit.
- **`AppScaffold` has no `bottomNavigationBar` slot.** Screens with a pinned
  action button put it in a `Column` under an `Expanded` body.
- **`maybeWhen` was 19 sites, not 12, and the raw error texts were 12, not
  16.** Both counts are now zero.
- **`_refreshDashboard` cannot become "a single refresh family".** Every card
  watches `todayProvider` or `dashboardRangeProvider` and invalidation does
  cascade — but invalidating the range would reset the period the owner
  picked. The list stays; it moved next to the providers and gained a test
  that fails when it falls behind.

## Notes

- **This is the movable part of the block.** Nothing depends on it, so it can slide
  behind [06](06-ledger-manual-allocation.md) and [07](07-ledger-statements.md) if
  feature work is more urgent. It must **not** slide behind
  [08](08-order-entry-swipe.md), which adds a repeating long-press to the order-entry
  screen whose per-tap rebuild this release fixes.
- **The ratchet is the reason this release is not optional.** Tokens that only half the
  app uses are worse than no tokens, because the next person cannot tell which half is
  correct.
