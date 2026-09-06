# 10b — Navigation & settings restructure

| | |
|---|---|
| **Target version** | `1.11.0+15` |
| **Type** | Feature |
| **Schema** | No change |
| **Requires** | [10a — Design system](10a-design-system.md) · [18 — Guardrails](18-foundation-guardrails.md) |
| **Absorbs** | Lifecycle audit **Phase 1** — application lifecycle |
| **Part of** | [10 — UI overhaul](10-ui-overhaul.md) |
| **Status** | **Built — awaiting the device pass.** See *Build notes* at the end |

## Why

**68% of the app's routes — 15 of 22 — sit behind a single tab called "Profile."**

That tab currently contains five masters, a price matrix, a document generator, a
data-safety tool, a dashboard customiser, a version checker, and the shop ledger. There
is no organising idea. It is a drawer that everything gets put in because there is
nowhere else to put it, and the name gives it away: a tab called "Profile" that
contains no profile.

The cost is measurable:

| Destination | Taps from home today |
|---|---|
| Any master | 2 |
| **Shop ledger** — the newest and most financially important screen | **4** + a visual scan |
| A product's price for a specific shop | 3 + two scans |
| **Outstanding across all shops** | **not reachable at all** |

Meanwhile a four-slot bottom bar spends one of its four slots on that filing cabinet,
giving it exactly the same prominence as the day's work. And the FAB opens the
Dashboard as a **push route outside the shell**, so the dashboard has no bottom bar and
no way back except system back. There is a dead line proving nobody noticed:
`_topLevelPaths` in `lib/app.dart` contains `'/dashboard'`, but that set is only read
inside `_ScaffoldWithNavBar`, which the dashboard route never builds.

By the time [06](06-ledger-manual-allocation.md)–[13](13-distribution-docs.md) land
there are ~28 destinations. Four slots and a flat nine-item list do not address 28
destinations.

**Explicitly out of scope:** any change to what a screen *does*. Every route reachable
before this release is reachable after it. This is rearrangement.

## Decisions

**Hybrid navigation** — bottom bar for daily jobs, drawer for everything else — was
taken 2026-08-19 and is binding. These decisions sit inside it.

| Question | Decision | Why the alternative lost |
|---|---|---|
| Side menu reach | **Mobile drawer only. Never desktop.** | Owner's call, 2026-08-26. Reference image 4's desktop sidebar is a *styling* reference for the drawer. No rail, no breakpoints, no wide layouts — now or ever |
| Centre FAB | **Quick-action sheet** — New order · Record payment · Add shop | Owner's call, 2026-08-26. Frees the single most prominent control from being a shortcut to one screen |
| Dashboard | **Becomes the 4th bottom-bar slot**, a real shell branch | It has to go somewhere once the FAB stops opening it, and the owner uses it daily. As a branch it keeps its bottom bar, keeps its own back stack, and the dead `_topLevelPaths` entry becomes live |
| Counter stock ([11](11-counter-stock.md)) | **Not built.** No drawer entry, no quick action, no slot | Dropped 2026-08-28 with the whole feature — this app does not count inventory |
| Roles | **None.** One bar, no role badge, no `currentRoleProvider` | Decision 2026-08-28: [14](14-supabase-auth.md) ships a single account with full access. Gating nobody from anything is code with no reader |
| Unshipped destinations | **Hidden, never shown-disabled** | Doc 10 left this open. A disabled row the user can never enable is noise — there is no unlock path, so it teaches nothing |
| Notification bell (reference image 4) | **Not built** | No notification system exists. A bell that opens nothing is worse than no bell |

This revises doc 10's original bottom-slot allocation (`Home · Billing [FAB] Kitchen ·
Counter`). The hybrid-navigation decision itself is untouched; only the slot contents
change, and they change because the FAB changed meaning.

## The structure

### Bottom bar

```
Home  ·  Billing   [ + ]   Kitchen  ·  Dashboard
```

Four daily jobs, and the centre `+`. Nothing that is configured monthly appears here.
One bar for one user — the role-scoped second bar in the original draft went with the
roles.

### The `+` sheet

```
  New order          → shop picker → /order/:shopId, on the selected date
  Record payment     → shop picker → record-payment sheet
  Add shop           → /settings/shops/new
```

Stated plainly: **the FAB is not the fastest path to a new order.** Home → shop row is
two taps and stays two taps. The FAB is the fastest path from *not being on Home*, and
it is the only path to "record a payment" that does not go through four screens today.
That is what it is for.

The shop picker is one reusable sheet: a search field and a recents row above the full
list.

### The drawer

Styled after reference image 4 — espresso ground, gold wordmark, grouped items, active
item in a cream pill, a divider before Settings, and the pinned outstanding card at the
bottom.

```
┌──────────────────────────────────┐
│  [logo]  {BrandConfig.appName}   │   ← brand seam from 10a
├──────────────────────────────────┤
│  ▸ Dashboard                     │
│                                  │
│  DAILY                           │
│    Today · Billing · Kitchen     │
│    Auto Suggestions       (15)   │
│                                  │
│  MONEY                           │
│    Outstanding                   │
│    Price Matrix                  │
│                                  │
│  CATALOGUE                       │
│    Shops · Products · Categories │
│                                  │
│  REPORTS                  (12)   │
│    Daily Sales · Product         │
│    Movement · Shop Ledger ·      │
│    Weekly Report          (16)   │
├──────────────────────────────────┤
│    Settings                      │
├──────────────────────────────────┤
│  Outstanding                     │   ← pinned, live
│  ₹1,16,717              →        │
│  Owed by 16 shops                │
└──────────────────────────────────┘
        v1.11.0 (build 15)
```

Entries marked with a doc number are **hidden until that doc ships**. At this release
the drawer is: Dashboard · DAILY (Today, Billing, Kitchen) · MONEY (Outstanding, Price
Matrix) · CATALOGUE (Shops, Products, Categories) · Settings. Ten entries, and it grows
into the shape above without another restructure.

Two things worth naming:

- **Catalogue sharing leaves the drawer entirely.** It is an action, not a destination,
  and it already lives as a share button on the Products screen
  (`product_list_screen.dart:59`). It stops being a navigation entry.
- **Standing Orders moves into Settings.** Default quantities per shop are
  configuration, not a place you go.

### The pinned outstanding card

Reference image 4's best idea: a module's headline number living permanently in the
navigation. It fixes the audit's finding that all-shops outstanding is currently
unreachable.

This needs the block's **only non-UI change** — two additive, read-only queries on
`ledger_dao.dart` over tables that already exist. No schema change, no writes:

```dart
Stream<OutstandingSummary> watchOutstandingSummary();   // total, shop count, oldest age
Stream<List<ShopOutstanding>> watchOutstandingByShop(); // per shop, desc by amount
```

Tapping the card opens the **existing Outstanding screen** at `/outstanding` — sorted by
outstanding descending, each row showing the amount and age.

> **Revised in build.** This section originally said "the existing Shops list in *Owes*
> mode". It was written before [07](07-ledger-statements.md) shipped
> `OutstandingListScreen`, which already answers exactly this question. Adding an Owes
> mode to the shop list would have left two screens answering it. The screen is reused
> and restyled onto [10a](10a-design-system.md)'s kit instead; no new screen, which was
> the point of the original wording.

### Settings

`/profile/*` → `/settings/*`. Grouped cards, a live-filter search field, and — the part
that matters — **each tile shows current state instead of static prose**:

| Today | After |
|---|---|
| "Manage shop details and status" | "18 active · 2 excluded from total" |
| "Set product prices per shop" | "212 of 504 prices set" — in amber |
| "Export or import all your data" | "Last exported 3 days ago" |
| "Manage bakery product catalog" | "34 products in 6 categories" |

Settings holds two groups:

- **Catalogue** — Shops · Categories · Products · Price Matrix, each with the live
  summary above. Also in the drawer's CATALOGUE group, which carries the same
  destinations without the summaries.
- **Configuration** — Business Info · Standing Orders · Dashboard sections ·
  Backup & Restore · Check for updates. About is the footer block, not a row.

> **Decided in build.** This section originally said masters move to the drawer and
> leave Settings entirely, which contradicted the state-summary table directly above
> it — three of its four examples are masters. The owner's call, 2026-08-29: keep them
> in both. The drawer is the fast way *there*; Settings is where you see what state
> they are in.

The search field is what makes ~28 destinations navigable, and it searches the whole
app's destinations, not just settings rows.

## Action items

### Shell

- [x] `lib/app.dart` — Dashboard becomes the **4th `StatefulShellBranch`** at
      `/dashboard`, replacing the Profile branch. Delete the top-level push route.
      `_topLevelPaths` becomes `{'/', '/orders', '/kitchen', '/dashboard'}` — the
      `'/dashboard'` entry finally does something and the `'/profile'` entry goes.
- [x] `lib/app.dart` — extract `_ScaffoldWithNavBar` into
      `lib/widgets/shell/app_shell.dart`. It gains the `Drawer` and the FAB sheet, and
      `app.dart` is left holding routing only. It is currently 300 lines of routing,
      theme and shell in one file; [10a](10a-design-system.md) takes the theme out and
      this takes the shell.
- [x] `lib/widgets/floating_nav_bar.dart` — 4 slots, built from a
      destination list rather than a hardcoded `_icons` tuple array. Person icon out,
      dashboard icon in. The 2 + gap + 2 layout and the entry animation are unchanged.
- [x] Drawer opens from a hamburger in `AppScaffold`'s leading slot
      ([10a](10a-design-system.md) already owns that widget). No edge-swipe-only drawer
      — it must have a visible affordance on every shell screen.

### Drawer

- [x] `lib/widgets/shell/app_drawer.dart` — new. Sections per the structure above,
      brand header from `brandProvider`, version footer.
- [x] `lib/widgets/shell/drawer_destinations.dart` — the destination list as **data**:
      label, icon, route, group, and a `shipped` flag. The drawer, the
      bottom bar and the settings search all read from this one list. Adding a
      destination in [12](12-dashboard-tabs.md) or [15](15-auto-order-suggestions.md)
      must be a one-line edit here, not three.
- [x] Back from a drawer destination returns to the **originating tab**, not to the
      drawer and not to Home.
- [x] Active-item highlighting reads the current route, and stays correct for nested
      routes (`/settings/shops/3/edit` highlights Shops).

### FAB quick actions

- [x] `lib/widgets/shell/quick_action_sheet.dart` — new. Three actions: New order,
      Record payment, Add shop.
- [x] `lib/widgets/shell/shop_picker_sheet.dart` — new, reusable: search field, recents
      row, full list. Used by New order and Record payment, and by
      [07](07-ledger-statements.md) later.
- [x] "New order" uses `selectedDateProvider`, not `DateTime.now()`. Picking a date and
      then creating an order for a different day is the kind of bug that only shows up
      in the ledger three weeks later.

### Routes

- [x] Move all 15 `/profile/*` routes to `/settings/*`.
- [x] **Redirects from every old path**, including the four parameterised ones
      (`/profile/shops/:id/edit`, `/profile/shops/:id/ledger`,
      `/profile/products/:id/edit`, `/profile/dashboard-settings/help`). There are
      **30 hardcoded `/profile` strings** in `lib/`; enumerate every one with
      `grep -rn "'/profile" lib/`, do not sample.
- [x] `AppRoutes` constants renamed to match. The 10 `AppRoutes.*` call sites update
      with them; the raw strings are the risk.
- [x] Ledger route moves to `/shops/:id/ledger` — it is not a setting and never was.

### Settings

- [x] `lib/screens/profile/profile_screen.dart` →
      `lib/screens/settings/settings_screen.dart`, rebuilt on
      [10a](10a-design-system.md)'s kit.
- [x] Live state summaries per the table above. Each is a small provider, each
      `autoDispose` per 10a's rule. **No N+1**: one aggregate per summary, following
      [doc 04](04-dashboard-performance.md)'s discipline.
- [x] Search field filtering `drawer_destinations.dart` **plus** settings rows, so one
      keystroke reaches any destination in the app.
- [x] "About" absorbs the branding block and version footer that
      `profile_screen.dart` renders inline today.

### Ledger queries

- [x] `lib/database/daos/ledger_dao.dart` — `watchOutstandingSummary()` and
      `watchOutstandingByShop()`, both read-only, both respecting `openingBalanceAt` and
      the **1-paisa epsilon helper** established in
      [doc 05](05-ledger-foundation.md). Reuse that helper; do not write a second
      comparison.
- [x] Zero-total orders are skipped, exactly as `watchShopLedger` already skips them.
      A shop whose only orders are empty must read ₹0 owed, not appear in the list.
- [x] `lib/providers/ledger_provider.dart` — `outstandingSummaryProvider`,
      `outstandingByShopProvider`.
- [x] ~~`shop_list_screen.dart` — "Owes" mode~~ **Superseded.** The drawer card opens
      the existing `/outstanding` screen, restyled onto the kit and now showing each
      row's age. See the revision note above.

### Application lifecycle — absorbed Phase 1

**Phase 1** of [`docs/flutter-lifecycle-audit.md`](../flutter-lifecycle-audit.md) lands
here because it rewrites `main.dart` and `app.dart`, which this release is already holding
open. It is the highest-value phase in that document and it closes a live defect: **an app
left open overnight reports yesterday as today, on every screen, forever.**

- [x] **Own the container.** Drop the hand-built `ProviderContainer` in `main.dart`; use
      `ProviderScope` with `overrides`. Today `databaseProvider`'s
      `ref.onDispose(db.close)` can never fire, and the SQLite handle is released only by
      process death.
- [x] **Move seeding off the startup path.** `runApp` first; seed inside an
      `AsyncNotifier` bootstrap provider that the root widget watches, wrapped in a `try`,
      rendering a real error screen on failure — which is only possible once a first frame
      exists. Today a throw during seeding means `runApp` is never called and the user
      gets a held splash that never resolves.
- [x] **Remove the splash route.** `flutter_native_splash` already covers cold start.
      Delete `SplashScreen`, make `/` the initial location, and call
      `FlutterNativeSplash.remove()` from the bootstrap provider's first successful data
      state — not from the line after `runApp`, where it currently tears the native splash
      down before the first frame is rasterised.
- [x] **One `AppLifecycleListener`** at the root. On `resumed`: invalidate `todayProvider`
      and, if the date rolled over, `selectedDateProvider`. On `paused`: flush the pending
      order-entry write. [Doc 14](14-supabase-auth.md)'s biometric gate hangs off this same
      listener later, which is a second reason to put it in properly now.
- [x] **Make "today" self-correcting.** `todayProvider` becomes a `Notifier` that
      invalidates itself on a timer scheduled for the next local midnight, *in addition* to
      the resume hook. The timer covers an app left foregrounded; the hook covers one that
      was not.
- [x] **Error observability.** `FlutterError.onError`,
      `PlatformDispatcher.instance.onError`, and a `ProviderObserver` logging
      `providerDidFail`. Local logging is enough to start — the seam is the point, and
      [10c](10c-screen-restyle.md)'s error views report into it.

**No auth, no roles, no session provider.** [14](14-supabase-auth.md) brings a single
account with full access. There is nothing to gate, and a fake gate built here is thrown
away there.

### Tests

- [x] `test/routing_test.dart` — new. Every old `/profile/*` path redirects to its
      `/settings/*` equivalent, parameterised paths included. This is the release's
      only real regression risk and it is cheap to cover.
- [x] `test/ledger_test.dart` — extend: outstanding summary against the existing FIFO
      fixture; a shop with only zero-total orders contributes ₹0 and does not appear;
      the summary equals the sum of the per-shop figures.

## Success criteria

- [x] **Every one of the 22 routes reachable before this change is still reachable.**
      Enumerate them against the list in [`docs/app-audit.md`](../app-audit.md) §2.1;
      do not sample.
- [x] Every old `/profile/*` URL redirects rather than 404s — proven by
      `test/routing_test.dart`, not by clicking.
- [ ] Reaching any destination takes at most **2 taps from any screen**.
- [x] The shop ledger drops from 4 taps to **2** (drawer → Outstanding → row, or
      Shops → row).
- [x] Total outstanding across all shops is visible **without opening a screen** — it is
      in the drawer.
- [x] The drawer's outstanding figure equals the sum of every shop's
      `watchShopStats().outstanding`, to the paisa.
- [x] Settings search reaches any destination in the app in **one keystroke**.
- [ ] Every settings tile's state summary is accurate against the real dataset — check
      each against the underlying screen, all six.
- [ ] Back from a drawer destination returns to the originating tab.
- [ ] Opening the Dashboard keeps the bottom bar, and back returns to the previous tab
      with its scroll position intact. Both are broken today.
- [x] No unshipped destination appears anywhere in the UI.
- [x] Adding a destination is a one-line change to `drawer_destinations.dart`. Prove it
      by adding a throwaway entry behind a flag and removing it again.
- [x] An integration test that advances the clock across midnight and fires
      `AppLifecycleState.resumed` sees Home report the new date. This is Phase 1's
      done-when, and the reason Phase 1 is in this release.
- [ ] Cold start reaches the first interactive frame with **no blank flash** between the
      native splash and the first screen.
- [x] A deliberate throw inside the bootstrap seed renders an error screen with a retry,
      not a held splash. **Covered by `test/lifecycle_test.dart`**, including the retry
      actually letting the app through, so this no longer needs the phone.

## Notes

- **The redirects are the whole risk in this release.** 30 hardcoded `/profile` strings,
  four of them parameterised. Everything else here is additive or cosmetic; this is the
  part that silently breaks a deep link and is not noticed for a week. It gets the test.
- **`drawer_destinations.dart` is the point of the release.** The reason navigation
  needed restructuring is that adding a destination previously meant editing a
  hardcoded tuple array, a hardcoded `_topLevelPaths` set, and a hand-written settings
  list. Four more destinations arrive in docs 12, 15 and 16. If they each still cost
  three edits, this release did not fix anything.
- **Doc 14's "no screen file changed as part of the DAO port" criterion** is carried by
  [14a](14a-repository-seam.md)'s repository seam, not by role gating written here.
  Nothing in this release needs to anticipate auth.
- **Phase 1 roughly doubles this release.** It is still the right place for it: both
  halves rewrite `app.dart` and `main.dart`, and splitting them means writing the shell
  twice.

## Revised by the owner — 2026-08-30

Four changes taken after the build, which supersede the decisions above.
They are recorded here rather than edited into the body, so the reasoning that
was live at the time stays readable.

| Was | Now | Why |
|---|---|---|
| 4-slot bar, centre quick-action FAB | **5 slots, no FAB** — Overview · Orders · Kitchen · Billing · Finances | The FAB spent the most prominent control in the app on a three-item menu. Each action has an obvious home: a new order is a tap on a shop in Orders, a payment is the FAB on Finances, a new shop is the FAB on the shop list |
| App opens on the shop list | **Opens on Overview** | Starting on data entry asked "what are you typing today" before answering "how is the business" |
| Outstanding is a drawer entry | **Finances is a tab** — outstanding, 30-day billed against collected, who owes, record payment | 10b made the figure visible; this gives it somewhere to live |
| Masters in Settings *and* the drawer | **Drawer only** | Reverses the 2026-08-29 call. Two doors to one room is how "Profile" became a filing cabinet |

`/` and `/orders` were renamed with it: `/` was the shop list and `/orders` was
billing, which is the opposite of what either name suggests. `/` is Overview,
`/orders` is the day's orders, `/billing` is billing.
`quick_action_sheet.dart` is deleted rather than left unused.

## Build notes — 2026-08-29

Built on `release/1.11.0-navigation`. `flutter analyze` clean, `flutter test` **203
green** (was 136), `tool/check_tokens.sh` passes with the screen count down from 396 to
365.

**Three deviations from the doc as written**, each noted in place above:

1. The drawer card opens the existing `/outstanding` screen rather than an "Owes" mode
   on the shop list. That section predated [07](07-ledger-statements.md) shipping the
   screen.
2. Masters stay in Settings *and* appear in the drawer. The doc contradicted itself;
   the owner chose both. **This note was wrong for one release.** The code shipped with
   them removed from Settings, and `settings_screen.dart` carried a comment arguing for
   the removal — so the doc said one thing and the screen did the other. The owner asked
   for them back on the device pass;
   [10b-device-pass](10b-device-pass.md) J4 restored the card and deleted the comment.
3. **A second DAO exception.** Doc 10 allowed one — the two outstanding queries on
   `ledger_dao.dart`. Settings' state summaries needed a second of exactly the same
   character: `PriceDao.watchCatalogueCoverage()`, read-only, additive, over tables that
   already exist. One aggregate, because reading it per shop would have been an N+1
   across 18 shops to fill in a subtitle — the thing [04](04-dashboard-performance.md)
   removed from the dashboard. No schema change; the chain stays frozen at v6.

**Three defects found by the new tests, all in this release's own code and all of which
would otherwise have shipped.**

The quick-action sheet **could not record a payment at all**: it popped its own sheet and
then tested `context.mounted` on that popped sheet's context, which is false by then, so
the payment sheet silently never opened. The sheet now only *chooses*; the FAB, which
outlives it, acts.

Settings tile **tap ripples were invisible** — `ListTile` paints ink on the nearest
`Material` ancestor and `AppCard` is a `DecoratedBox`, so every highlight was drawn
behind the card.

And the resume hook read
`todayProvider` to answer "did the date change while we were away?" — but that provider
is lazy, so the read *built* it from the clock as it then was and compared the new day
against itself. It could never fire, and it would have failed exactly where it matters:
Home watches the selected date, not today, so nothing had built `todayProvider` first.
`AppLifecycleScope` now tracks the day it last knew, seeded in `initState`, which also
starts the midnight timer at launch rather than whenever a screen first wants a date.

### What still needs the phone

Five criteria above are unticked because a container cannot honestly tick them. A sixth
— the bootstrap error screen — was moved into `test/lifecycle_test.dart` instead, which
is a better place for it than a manual step nobody will repeat.

| Criterion | How to check |
|---|---|
| Settings tile summaries are accurate | Open each of the ten tiles and compare its subtitle against the screen it opens |
| Reaching any destination is at most 2 taps | Walk it. The route table supports it; only use proves it |
| Back from a drawer destination returns to the originating tab | Open Kitchen, drawer → Shops, back. Expect Kitchen |
| Dashboard keeps the bottom bar, back restores scroll position | Both were broken before this release |
| Cold start has no blank flash | Watch the hand-off from the native splash. This is the `FlutterNativeSplash.remove()` move onto a post-frame callback |

Also still open from [18](18-foundation-guardrails.md): the four 10a performance figures
have a pass but no recorded numbers. This release rewrote the router and deleted the
splash route, which is exactly what cold start would notice — worth capturing a figure
while the phone is out.

### The device pass happened — 2026-09-05

The owner ran this branch on the phone and came back with 30-odd points. They are
planned in [10b — Device pass](10b-device-pass.md), which ships on this branch as part
of `1.11.0+15`. Two of them are dead features: order entry's back button jumps to the
Dashboard, and the day-of-week heatmap has never rendered with real data.

Build note 2 above is **wrong**. It says the masters stay in Settings as well as the
drawer; commit `ddd08d8` removed the Catalogue card and `settings_screen.dart` carries a
comment arguing they should not be there. The owner has asked for both again. The device
pass doc fixes the code and this note together.

**The version is deliberately not bumped.** `pubspec.yaml` stays at `1.10.0+14` so that
merging cannot cut a release before the device pass. Bump to `1.11.0+15` as the last
commit on this branch, per the roadmap.
