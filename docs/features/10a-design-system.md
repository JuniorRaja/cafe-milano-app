# 10a — Design system & UI foundation

| | |
|---|---|
| **Target version** | `1.10.0+14` — **ships with [18](18-foundation-guardrails.md)** |
| **Type** | Foundation (minor — the owner opens a different-looking app) |
| **Schema** | No change |
| **Part of** | [10 — UI overhaul](10-ui-overhaul.md) |
| **Followed by** | [10b — Navigation](10b-navigation.md), [10c — Screen restyle](10c-screen-restyle.md) |
| **Status** | **Built, awaiting commit** — see *Build notes* at the end |

## Why

Twelve modules were built one at a time, each in the shape that was convenient that
week. Nothing was ever shared. The result, measured across `lib/`:

| | Count |
|---|---|
| Distinct `fontSize:` literals | **14** |
| `Theme.of(context).textTheme` uses in 12,029 lines | **2** |
| `Colors.grey.shadeNNN` / `Colors.grey[NNN]` | **111** |
| Distinct `BorderRadius.circular(n)` values | **8** |
| `EdgeInsets` literals | **117** |
| `RepaintBoundary` | **0** |
| Screens hand-rolling a header · screens using `AppBar` | **5 · 15** |

Every one of those numbers is a decision made repeatedly, slightly differently each
time. The eye reads that inconsistency as "unfinished" long before it reads any single
screen as ugly. **This is not a taste problem and it is not fixed by restyling
screens** — restyling 20 screens without tokens produces 20 more sets of literals.

The same absence explains the slowness. There is no shared list row, so there is no
place to have put a `RepaintBoundary`; there is no shared background, so a runtime
Gaussian blur ended up under every screen; there is no provider convention, so none of
the 35 providers is `autoDispose`. Full detail in [`docs/app-audit.md`](../app-audit.md) §4.

This doc ships the missing layer: **tokens, a component kit, a brand seam, and the
four performance fixes**. It changes how the app looks everywhere, because the theme
reaches everywhere, but it rebuilds no screen. [10c](10c-screen-restyle.md) does that.

**Explicitly out of scope:** navigation ([10b](10b-navigation.md)), screen layout
changes ([10c](10c-screen-restyle.md)), dark mode, and any DAO or schema change.

### On dark mode

Not built, and not designed around. The app is used at 5 a.m. in a kitchen and on a
delivery round; a cream ground at full brightness is the correct choice for both.
Tokens are defined as a named set rather than raw constants, so a second set is
possible later — but no screen may branch on brightness, and no `Theme.of(context)
.brightness` check is permitted in this release. A half-built dark mode is worse than
none.

## The token set

One file, `lib/theme/tokens.dart`. These are the values — they are decided here, not
during implementation.

### Colour

Brand colours resolve through `BrandConfig` (below). Everything else is fixed.

```
BRAND  (from BrandConfig — defaults shown are Milano's)
  brandPrimary     #FFC000   gold       FAB, primary CTA, active chip fill, accents
  brandOnPrimary   #2B1A12              text and icons drawn on gold
  brandDeep        #4A2C2A   espresso   primary buttons, titles, active icons
  brandDeepest     #3A2018   dark roast drawer ground, hero cards
  brandMark        #B71C1C   maroon     logo mark only — never a UI colour

SURFACE
  bg               #FFFBF5   cream page ground (today's kSurface, unchanged)
  surface          #FFFFFF   cards, sheets
  surfaceMuted     #F7F1E8   inset rows, table headers, disabled fills
  border           #EFE6DA   hairlines, card outlines, dividers

TEXT   (replaces all 111 ad-hoc greys)
  textPrimary      #2B1A12
  textSecondary    #7A6A5F
  textTertiary     #A89A8E
  textOnDark       #FFF7EC

SEMANTIC  (each pairs a foreground with a soft fill)
  positive #1F9254 / positiveSoft #E6F4EC   growth, paid, collected
  negative #D64545 / negativeSoft #FCEBEB   overdue, decline, unpaid
  warning  #E8A33D / warningSoft  #FDF3E3   needs review, partial, incomplete
  info     #6C5CE7 / infoSoft     #EFEDFC   reasons, hints, explanations
```

Two rules that are easy to get backwards:

- **Brand colour never carries meaning.** Gold is emphasis; it is not "good". A figure
  that is up is `positive`, never gold. Today's app uses gold and brown for everything
  including status, which is why nothing on screen reads as urgent.
- **Semantic colour is never decorative.** If a row is red, something is wrong with it.
  This is the rule that makes reference image 3's risk donut legible at a glance, and
  it only holds if it holds everywhere.

### Type

**Eight steps replacing fourteen sizes**, wired into `ThemeData.textTheme` so
`Theme.of(context).textTheme` finally means something.

The face is **Raleway**, swapped in from Quicksand on 2026-08-29 at the owner's
call: Quicksand is a rounded display type and the app is a billing tool. Four
static weights (400/500/600/700), instanced from the Google Fonts variable
master and bundled - this app has to work with no signal, so a runtime font
download is not an option.

Two things to know about the swap. Raleway carries a **smaller x-height** than
Quicksand, so the same `fontSize:` reads smaller and lighter on the phone; if a
step looks thin, move its weight up before you move its size. And the four files
are **164 KB each against Quicksand's 78 KB**, so the APK grows ~343 KB. They are
deliberately *not* subset: shop and product names are free text the owner types,
and a subset font turns anything outside it into tofu.

| Token | Size / weight | Used for |
|---|---|---|
| `displayL` | 28 / w700 | Hero figures — `₹116,717` |
| `titleL` | 22 / w700 | Screen titles |
| `titleM` | 17 / w600 | Card titles, shop names |
| `titleS` | 15 / w600 | Row titles |
| `body` | 14 / w500 | Body text |
| `bodyS` | 13 / w500 | Secondary rows, subtitles |
| `label` | 12 / w600 | Chips, buttons, table headers |
| `caption` | 11 / w600, `+0.8` tracking, uppercase | Section captions |

`FontWeight.bold` is banned — it and `w700` were both in use, interchangeably. Weights
come from the token or not at all.

### Spacing, radius, elevation

```
SPACE    s1 4 · s2 8 · s3 12 · s4 16 · s5 24 · s6 32      (replaces 117 literals)
RADIUS   rS 10  chips, fields, small controls
         rM 16  cards, sheets, inputs
         rL 24  hero cards, bottom sheets
         rFull  pills and avatars                          (replaces 8 values)
SHADOW   shadowCard    y2  blur 12  black 6%
         shadowRaised  y6  blur 20  black 10%              (replaces withAlpha guesswork)
```

Material `elevation:` is not used. Two shadows, both defined here.

## Brand seam

White-labelling ([17](17-white-label.md)) ships long after this. The *seam* ships now,
because adding it at token-definition time costs almost nothing and retrofitting it
means touching every screen a second time.

```dart
class BrandConfig {
  final String appName;        // 'Milano Orders'
  final String shortName;      // 'Milano'
  final String logoAsset;
  final Color  primary, deep, deepest, mark;
  final String currencySymbol; // '₹'
  final String locale;         // 'en_IN'
  static const milano = BrandConfig(...);
}

final brandProvider = Provider<BrandConfig>((ref) => BrandConfig.milano);
```

One rule, and it is absolute: **no UI string may contain "Milano", "Cafe Milano" or
"bakery".** There are 19 such sites today, including `lib/app.dart:192`
(`title: 'Milano Orders'`), and three inside `profile_screen.dart` — a `RichText`
wordmark, a `'Daily Order Manager'` tagline, and a `'CAFE MILANO'` footer. All resolve
through `brandProvider`.

Business-domain wording — "shop", "kitchen" — stays hardcoded in this release.
Making *terminology* configurable is [17](17-white-label.md)'s problem, and guessing at
its shape now would be building an abstraction nobody asked for.

## Component kit

`lib/widgets/ui/`. Each entry replaces something currently copy-pasted, and each maps
to a pattern in the reference screens.

| Component | Replaces | Reference |
|---|---|---|
| `AppScaffold` | 5 hand-rolled headers **and** 15 `AppBar`s | — |
| `AppCard` | ~20 `Card` + `RoundedRectangleBorder` sites | all |
| `StatBand` | nothing — new | image 2's "16/18 shops · ₹24,680 ↑8%" |
| `HeroStatCard` | nothing — new | image 3's outstanding card |
| `FilterChipRow` | ad-hoc chip rows | image 2's "All Shops 18 · Needs Review 2" |
| `SectionHeader` | inline `Row` + `Spacer` + `Text` | image 3's "At Risk Shops · View all" |
| `ListRow` | `ShopOrderCard` and 6 similar | image 3's at-risk row |
| `StatusBadge` | 3 private `_StatusChip` classes | image 2's Beta pill |
| `DeltaPill` | nothing — new | image 2's `+₹240` / `−₹120` |
| `MiniTable` | nothing — new | image 2's Item/Usual/Suggested/Change table |
| `NoteBanner` | nothing — new | image 2's lavender "Reason:" banner |
| `AppButton` | 4 button themes in `app.dart` | image 1's Save Shop / Add Category |
| `EmptyState` | 6 inert grey-icon empty states | — |
| `AppSkeleton` | 12 bare `CircularProgressIndicator`s | — |

`AppScaffold` is the important one. It is the single header idiom, and it takes
`caption`, `title`, `actions`, and an optional `bottom` slot for a date selector or
tab bar — which is exactly the composition all five hand-rolled headers already
express, just five times.

`EmptyState` **requires an action**. Today's empty states are a grey icon and one line
of grey text, which tell the user they have nothing without telling them what to do
about it. An empty shop list should offer "Add your first shop", not sympathy.

## Action items

### Tokens and theme

- [x] `lib/theme/tokens.dart` — colour, type, spacing, radius, shadow, exactly as
      specified above. Plain `const`s and a `TextTheme` builder; no code generation.
- [x] `lib/theme/app_theme.dart` — build `ThemeData` from tokens. Move the four
      button themes, `listTileTheme`, `navigationBarTheme` and `tabBarTheme` out of
      `lib/app.dart`, which currently holds ~90 lines of theme inline.
- [x] `lib/app.dart` — keep `kBrandGold` / `kBrandBrown` / `kSurface` as
      **`@Deprecated` aliases** onto the new tokens. 60+ files import them; removing
      them in this release turns a foundation change into a 60-file diff.
      [10c](10c-screen-restyle.md) deletes them once nothing imports them.
- [x] Set `ColorScheme` fields properly so Material's own widgets (dialogs, pickers,
      snackbars) inherit the palette. Today they fall back to `fromSeed` defaults and
      look like a different app — most visible in `showDatePicker`, which the date
      selector opens constantly.

### Brand seam

- [x] `lib/theme/brand_config.dart` + `brandProvider`, per above.
- [x] Replace all **19** hardcoded brand strings. Enumerate them from
      `grep -rn "Milano\|MILANO" lib/ --include=*.dart`; do not sample.
- [x] `MaterialApp.router(title:)` reads `BrandConfig.appName`.
- [x] Currency formatting goes through one helper reading `BrandConfig.currencySymbol`
      and `locale`. `NumberFormat('#,##0')` with a literal `₹` is written out at
      ~30 call sites today, and Indian digit grouping is a real formatting difference,
      not a symbol swap.

### Component kit

- [x] Build the 14 components above in `lib/widgets/ui/`, each with a `///` doc comment
      naming what it replaces.
- [x] `lib/widgets/ui/README.md` — one screenshot-free page: which component to reach
      for, and the rule that new UI composes from the kit rather than from `Container`.
- [x] **Do not migrate any screen in this release.** The kit ships unused except by the
      theme. That is deliberate: a foundation release whose diff also touches 20 screens
      cannot be reviewed, and cannot be reverted if a token turns out wrong.
      The one exception below is the background.

### Performance

Four fixes. Each is named in [audit §4](../app-audit.md) with its measurement.

- [x] **Kill the runtime blur.** `lib/widgets/app_background.dart` currently decodes a
      144 KB PNG at full resolution, scales it to cover, runs a Gaussian blur through
      `ImageFiltered`, and composites at 50% `Opacity` — with no `RepaintBoundary`.
      Both `ImageFiltered` and `Opacity` force `saveLayer`, and it sits under **every
      shell screen**, repainting on every scroll and every animated frame.
      Pre-blur the asset at build time, drop `ImageFiltered` and `Opacity` entirely,
      bake the 50% into the asset, add `cacheWidth`, and wrap the whole thing in a
      `RepaintBoundary`. This is the single largest rendering cost in the app and it is
      decorative.
- [x] **`autoDispose` every family provider.** 0 of 35 providers use it today. Every
      distinct argument to `orderSummariesForDateProvider(date)`,
      `kitchenLinesForDateProvider(date)`, `orderWithLinesProvider(id)`,
      `pricesForShopProvider(shopId)`, `shopLedgerProvider(...)`,
      `shopStatsProvider(shopId)` and `billStatusProvider(orderId)` creates an instance
      that lives for the process lifetime holding an open Drift stream. Step back
      fourteen days on the home screen and fourteen live subscriptions re-run on every
      write. **This is the cause that gets worse over a session**, and therefore the one
      most likely to match the reported slowness.
      Keep `databaseProvider`, `selectedDateProvider`, `dashboardSettingsProvider`,
      `brandProvider` and the unparameterised master lists non-`autoDispose` — they are
      genuinely app-lifetime. Everything keyed on an argument becomes `autoDispose`.
- [x] **Unblock the splash.** `splash_screen.dart` runs a fixed 1200 ms
      `AnimationController` and navigates on `AnimationStatus.completed`. Nothing is
      being waited on — the animation *is* the wait, on top of the native splash.
      Navigate when the database is open **or** after 400 ms, whichever is later, and
      cap the whole thing at 600 ms. Add `cacheWidth: 320` to the logo: it is a 284 KB
      PNG decoded at full resolution to be drawn at 160×160.
- [x] **Fix the stagger.** `StaggeredFadeIn` gives each row `30ms × index` (capped at
      12) plus a 250 ms fade, so the last visible row of an 18-shop list appears
      **360 ms after the data is ready** and the list animates for ~600 ms. Each row is
      also its own `StatefulWidget`, `Future.delayed` and `setState`.
      Replace it with a single 150 ms fade on the list as a whole. Keep the file and its
      name so the diff stays legible; replace its body.
- [ ] ~~Convert the **6** eager `ListView(` sites to `ListView.builder` (against 4 already
      correct). The price matrix and settings lists build every row up front.~~
      **Not done — see Build notes.** All six pass a static `children:` literal, so
      `.builder` over that literal is not lazy and buys nothing; the price matrix was
      already lazy. Deferred to [10c](10c-screen-restyle.md).
- [x] `RepaintBoundary` around `ListRow` and around each dashboard chart card.

### Guard rails

- [x] `tool/check_tokens.sh` — fails if `lib/screens/` or `lib/widgets/` (excluding
      `lib/widgets/ui/`) contains `Colors.grey`, a `fontSize:` literal, or
      `BorderRadius.circular(`. **Expected to fail on day one** — it is a ratchet for
      [10c](10c-screen-restyle.md), not a gate for this release. Wire it into CI as a
      reporting step that prints the count, and flip it to blocking at the end of 10c.
- [x] Record the starting counts in the script's header comment so the ratchet is
      visible: 111 greys, 14 font sizes, 8 radii.

### Tests

Deliberately light. The kit is presentational; the roadmap's standing position is that
UI does not need unit tests, and nothing here carries money or counts.

- [x] `test/widget_test.dart` — extend so the existing smoke tests build under the new
      theme. If it passes unchanged, the theme was wired correctly.
- [x] One golden-free widget test per kit component asserting it builds and renders its
      text. Enough to catch a null token or a bad `TextTheme` key, no more.
- [x] **No test asserts a colour value.** Tokens are meant to change — that is the point
      of [17](17-white-label.md) — and a test that pins `#FFC000` makes the seam useless.

## Success criteria

- [x] `lib/theme/tokens.dart` is the only place any colour, size, radius or shadow is
      defined. Verified by `tool/check_tokens.sh` against `lib/widgets/ui/`, which must
      be clean even though the screens are not yet.
- [x] `Theme.of(context).textTheme` resolves all 8 type steps.
- [x] All 14 kit components exist, build, and are documented in
      `lib/widgets/ui/README.md`.
- [x] `grep -rn "Milano\|MILANO" lib/ --include=*.dart` returns **zero** UI-string hits.
      Non-UI hits (the Drift `milano_orders` database name, backup file naming) are
      listed explicitly in the doc as permitted.
- [x] Changing `BrandConfig.milano.primary` to an obviously wrong colour restyles the
      whole app, including the FAB, buttons, chips and active nav state, with no other
      edit. This is the test that the seam is real.
- [ ] Cold start to first interactive frame drops from ~1.2 s + native splash to
      **under 600 ms** + native splash, measured on the owner's device.
- [ ] An 18-shop home list is fully visible **within 200 ms** of data arriving, down
      from ~600 ms.
- [ ] Scrolling the home list holds 60 fps with the DevTools performance overlay clean
      of `saveLayer` warnings from the background.
- [ ] Visiting 14 consecutive dates on the home screen, then returning to today, leaves
      **one** live `watchOrderSummaries` subscription. Verified with a counter in the
      DAO or the Riverpod observer, not by inspection.
- [~] `flutter test` passes. `flutter analyze` is clean apart from the intentional
      `@Deprecated` alias warnings, whose count is recorded in the PR description so
      [10c](10c-screen-restyle.md) can drive it to zero.
      **131 pass, 84 deprecation warnings, 0 other analyzer issues.** One test still
      fails — `migration_test.dart`, `v4 -> v5 upgrade` — and failed identically on
      `60b9662` before this work started. It is a schema-migration bug, the one area
      10a does not touch, so it is left for its own fix.
- [ ] Every screen still renders and every route still works. Nothing was rebuilt in
      this release, so anything that changed shape is a bug.

## Notes

- **Why minor, not patch.** This doc originally argued for a patch: no new capability,
  so no minor bump. The [roadmap](../roadmap.md) rule changed on 2026-08-28. The test is
  now what the owner sees when he opens the app, and the whole app changes colour, type
  and speed here. That is a minor bump.
- **It does not ship alone.** [18](18-foundation-guardrails.md) rides in the same
  release: the guardrails, the agent docs, the red migration test, and the order-entry
  data-loss fix. 10a on its own is a look change with a failing test and no ratchet.
- **Why the kit ships unused.** Reviewing a diff that introduces tokens *and* rewrites
  20 screens is not possible, and reverting it is worse. Ship the layer, prove the
  theme did not break anything, then migrate screens against a fixed target.
- **The deprecated aliases are load-bearing.** 60+ files import `kBrandGold` and
  friends from `lib/app.dart`. They stay until [10c](10c-screen-restyle.md) empties
  them, and the analyzer warning count is the progress bar.

## Build notes

Written when this doc was implemented. The four items below are the only places the
build departs from the plan above, or leaves something for a device.

- **The 6 eager `ListView(` sites were deliberately not converted.** All six —
  `backup_restore`, `business_info_form`, `dashboard_settings`, `product_form`,
  `profile_screen`, `shop_form` — pass a *static* `children:` literal of six to
  fifteen heterogeneous widgets. `ListView.builder` over a `<Widget>[...]` literal
  constructs every child exactly as eagerly, so the conversion buys nothing and costs
  six screens of readability in a release whose own rule is "do not migrate any
  screen". The audit's example, the price matrix, was already `ListView.separated`
  before this work. Reopen this in [10c](10c-screen-restyle.md), where the screens are
  being rebuilt anyway and the children become data-driven.
- **Four success criteria need the owner's device** and are left unticked: cold start
  under 600 ms, the 18-shop list visible within 200 ms, 60 fps with a clean `saveLayer`
  overlay, and one live `watchOrderSummaries` subscription after fourteen dates. The
  code changes they measure are all in (`app_background.dart`, `staggered_fade_in.dart`,
  `splash_screen.dart`, 12 `autoDispose` families); the numbers are not.
- **The version was retargeted after the build.** The header originally read `1.7.1+10`.
  By the time this work finished the app had reached `1.9.2+13`, and the bump rule had
  changed, so 10a ships as **`1.10.0+14`** together with [18](18-foundation-guardrails.md).
  `pubspec.yaml` takes that bump at the end of the release branch, not at first commit.
- **Permitted non-UI "Milano" hits**, per the success criterion. Four `debugPrint`
  log tags (`[MilanoOrders]` in `app_database.dart` and `seed_data.dart`), the Drift
  database filename `milano_orders.db`, the backup filename prefix
  `cafe-milano-backup-` (changing it would orphan every backup already on the owner's
  device — the restore scan matches on it), and `BrandConfig.milano` itself, which is
  where the string is supposed to live.

### Also landed, not in the plan

- `lib/providers/read_once.dart` — `ref.readStreamOnce` / `ref.readFutureOnce`.
  `autoDispose` turned three existing `ref.read(provider.future)` calls into hangs: a
  bare `read` registers no listener, so the provider is disposed on the next tick and
  the future never completes. The three call sites are the ledger statement export and
  the two bill shares.
- `deprecated_member_use_from_same_package: true` in `analysis_options.yaml`. Without
  it the `@Deprecated` aliases are invisible to `flutter analyze` and there is no
  progress bar for 10c. Current count: **84**.
- `tool/blur_background.py` — regenerates `bg-vector-blurred.png` from `bg-vector.png`.
  The source art stays in the repo but is no longer bundled, which also drops 145 KB
  from the build.
- Five stale assertions in `test/widget_test.dart`, red before this work started: the
  home header is two `Text`s rather than `Shops · N shops`, `ShopOrderCard` draws its
  Pending chip even for a shop with no order, and the kitchen share control is now an
  always-present disabled `IconButton` rather than a conditional FAB. The harness also
  now builds under `buildAppTheme` instead of an ad-hoc orange seed, which is what
  makes them a theme smoke test at all.
