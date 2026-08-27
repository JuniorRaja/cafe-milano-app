# 10b — Navigation & settings restructure

| | |
|---|---|
| **Target version** | `1.8.0+11` |
| **Type** | Feature |
| **Schema** | No change |
| **Requires** | [10a — Design system](10a-design-system.md) |
| **Part of** | [10 — UI overhaul](10-ui-overhaul.md) |
| **Status** | Ready |

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
| Counter stock ([11](11-counter-stock.md)) | Drawer DAILY group + a FAB quick action; a **bottom slot only for the staff role** | Doc 10's original outline gave it slot 4. But it is a staff job, and role-scoping the bar handles that better than spending the owner's fourth slot on it |
| Unshipped destinations | **Hidden, never shown-disabled** | Doc 10 left this open. A disabled row the user can never enable is noise — there is no unlock path, so it teaches nothing |
| Notification bell (reference image 4) | **Not built** | No notification system exists. A bell that opens nothing is worse than no bell |

This revises doc 10's original bottom-slot allocation (`Home · Billing [FAB] Kitchen ·
Counter`). The hybrid-navigation decision itself is untouched; only the slot contents
change, and they change because the FAB changed meaning.

## The structure

### Bottom bar — role-scoped

```
owner / manager     Home  ·  Billing   [ + ]   Kitchen  ·  Dashboard
staff                        Kitchen   ·  Counter          (2 slots, no FAB)
```

Four daily jobs, and the centre `+`. Nothing that is configured monthly appears here.
The staff bar is written now and inert until [14](14-supabase-auth.md) makes the role
real — verified by inspection, since it cannot be exercised.

### The `+` sheet

```
  New order          → shop picker → /order/:shopId, on the selected date
  Record payment     → shop picker → record-payment sheet
  Add shop           → /settings/shops/new
  Count stock        → /counter                         (after doc 11)
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
│          Owner                   │   ← role badge, from session_provider
├──────────────────────────────────┤
│  ▸ Dashboard                     │
│                                  │
│  DAILY                           │
│    Today · Billing · Kitchen     │
│    Counter Stock          (11)   │
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
│    Movement · Counter Stock ·    │
│    Shop Ledger · Weekly   (16)   │
├──────────────────────────────────┤
│    Settings                      │
├──────────────────────────────────┤
│  Outstanding                     │   ← pinned, live
│  ₹1,16,717              →        │
│  Owed by 16 shops                │
└──────────────────────────────────┘
        v1.8.0 (build 11)
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

Tapping the card opens the **existing Shops list in "Owes" mode** — same screen, sorted
by outstanding descending, each row showing the amount and age, using the "View Ledger"
action that already exists. No new screen in this release.
[Doc 07](07-ledger-statements.md) later promotes this into the real Outstanding screen
with statements, and reuses both queries; it should be updated to say so.

### Settings

`/profile/*` → `/settings/*`. Grouped cards, a live-filter search field, and — the part
that matters — **each tile shows current state instead of static prose**:

| Today | After |
|---|---|
| "Manage shop details and status" | "18 active · 2 excluded from total" |
| "Set product prices per shop" | "212 of 504 prices set" — in amber |
| "Export or import all your data" | "Last exported 3 days ago" |
| "Manage bakery product catalog" | "34 products in 6 categories" |

Settings holds configuration only: **Business Info · Standing Orders · Dashboard
sections · Backup & Restore · Check for updates · About**. Masters moved to the
drawer's CATALOGUE group.

The search field is what makes ~28 destinations navigable, and it searches the whole
app's destinations, not just settings rows.

## Action items

### Shell

- [ ] `lib/app.dart` — Dashboard becomes the **4th `StatefulShellBranch`** at
      `/dashboard`, replacing the Profile branch. Delete the top-level push route.
      `_topLevelPaths` becomes `{'/', '/orders', '/kitchen', '/dashboard'}` — the
      `'/dashboard'` entry finally does something and the `'/profile'` entry goes.
- [ ] `lib/app.dart` — extract `_ScaffoldWithNavBar` into
      `lib/widgets/shell/app_shell.dart`. It gains the `Drawer` and the FAB sheet, and
      `app.dart` is left holding routing only. It is currently 300 lines of routing,
      theme and shell in one file; [10a](10a-design-system.md) takes the theme out and
      this takes the shell.
- [ ] `lib/widgets/floating_nav_bar.dart` — 4 slots, role-scoped, built from a
      destination list rather than a hardcoded `_icons` tuple array. Person icon out,
      dashboard icon in. The 2 + gap + 2 layout and the entry animation are unchanged.
- [ ] Drawer opens from a hamburger in `AppScaffold`'s leading slot
      ([10a](10a-design-system.md) already owns that widget). No edge-swipe-only drawer
      — it must have a visible affordance on every shell screen.

### Drawer

- [ ] `lib/widgets/shell/app_drawer.dart` — new. Sections per the structure above,
      brand header from `brandProvider`, role badge, version footer.
- [ ] `lib/widgets/shell/drawer_destinations.dart` — the destination list as **data**:
      label, icon, route, group, minimum role, and a `shipped` flag. The drawer, the
      bottom bar and the settings search all read from this one list. Adding a
      destination in [11](11-counter-stock.md), [12](12-dashboard-tabs.md) or
      [15](15-auto-order-suggestions.md) must be a one-line edit here, not three.
- [ ] Back from a drawer destination returns to the **originating tab**, not to the
      drawer and not to Home.
- [ ] Active-item highlighting reads the current route, and stays correct for nested
      routes (`/settings/shops/3/edit` highlights Shops).

### FAB quick actions

- [ ] `lib/widgets/shell/quick_action_sheet.dart` — new. Three actions now, a fourth
      after [11](11-counter-stock.md). Reads the same role gate.
- [ ] `lib/widgets/shell/shop_picker_sheet.dart` — new, reusable: search field, recents
      row, full list. Used by New order and Record payment, and by
      [07](07-ledger-statements.md) later.
- [ ] "New order" uses `selectedDateProvider`, not `DateTime.now()`. Picking a date and
      then creating an order for a different day is the kind of bug that only shows up
      in the ledger three weeks later.

### Routes

- [ ] Move all 15 `/profile/*` routes to `/settings/*`.
- [ ] **Redirects from every old path**, including the four parameterised ones
      (`/profile/shops/:id/edit`, `/profile/shops/:id/ledger`,
      `/profile/products/:id/edit`, `/profile/dashboard-settings/help`). There are
      **30 hardcoded `/profile` strings** in `lib/`; enumerate every one with
      `grep -rn "'/profile" lib/`, do not sample.
- [ ] `AppRoutes` constants renamed to match. The 10 `AppRoutes.*` call sites update
      with them; the raw strings are the risk.
- [ ] Ledger route moves to `/shops/:id/ledger` — it is not a setting and never was.

### Settings

- [ ] `lib/screens/profile/profile_screen.dart` →
      `lib/screens/settings/settings_screen.dart`, rebuilt on
      [10a](10a-design-system.md)'s kit.
- [ ] Live state summaries per the table above. Each is a small provider, each
      `autoDispose` per 10a's rule. **No N+1**: one aggregate per summary, following
      [doc 04](04-dashboard-performance.md)'s discipline.
- [ ] Search field filtering `drawer_destinations.dart` **plus** settings rows, so one
      keystroke reaches any destination in the app.
- [ ] "About" absorbs the branding block and version footer that
      `profile_screen.dart` renders inline today.

### Ledger queries

- [ ] `lib/database/daos/ledger_dao.dart` — `watchOutstandingSummary()` and
      `watchOutstandingByShop()`, both read-only, both respecting `openingBalanceAt` and
      the **1-paisa epsilon helper** established in
      [doc 05](05-ledger-foundation.md). Reuse that helper; do not write a second
      comparison.
- [ ] Zero-total orders are skipped, exactly as `watchShopLedger` already skips them.
      A shop whose only orders are empty must read ₹0 owed, not appear in the list.
- [ ] `lib/providers/ledger_provider.dart` — `outstandingSummaryProvider`,
      `outstandingByShopProvider`.
- [ ] `lib/screens/settings/shops/shop_list_screen.dart` — "Owes" mode: sorted by
      outstanding descending, amount and age per row, reached from the drawer card.

### Role gating

- [ ] `lib/providers/session_provider.dart` — new, one line:
      `currentRoleProvider` returns `AppRole.owner`, hardcoded.
      [Doc 14](14-supabase-auth.md) swaps the body for the real session and **no screen
      changes**. If a screen has to change there, the gating was written wrong here.
- [ ] Bottom bar, drawer and quick actions all gate off it. No local login screen — a
      fake auth built now is thrown away in doc 14.

### Tests

- [ ] `test/routing_test.dart` — new. Every old `/profile/*` path redirects to its
      `/settings/*` equivalent, parameterised paths included. This is the release's
      only real regression risk and it is cheap to cover.
- [ ] `test/ledger_test.dart` — extend: outstanding summary against the existing FIFO
      fixture; a shop with only zero-total orders contributes ₹0 and does not appear;
      the summary equals the sum of the per-shop figures.

## Success criteria

- [ ] **Every one of the 22 routes reachable before this change is still reachable.**
      Enumerate them against the list in [`docs/app-audit.md`](../app-audit.md) §2.1;
      do not sample.
- [ ] Every old `/profile/*` URL redirects rather than 404s — proven by
      `test/routing_test.dart`, not by clicking.
- [ ] Reaching any destination takes at most **2 taps from any screen**.
- [ ] The shop ledger drops from 4 taps to **2** (drawer → Outstanding → row, or
      Shops → row).
- [ ] Total outstanding across all shops is visible **without opening a screen** — it is
      in the drawer.
- [ ] The drawer's outstanding figure equals the sum of every shop's
      `watchShopStats().outstanding`, to the paisa.
- [ ] Settings search reaches any destination in the app in **one keystroke**.
- [ ] Every settings tile's state summary is accurate against the real dataset — check
      each against the underlying screen, all six.
- [ ] Back from a drawer destination returns to the originating tab.
- [ ] Opening the Dashboard keeps the bottom bar, and back returns to the previous tab
      with its scroll position intact. Both are broken today.
- [ ] No unshipped destination appears anywhere in the UI.
- [ ] Role gating is present and inert, verified by inspection — it cannot be exercised
      until [14](14-supabase-auth.md).
- [ ] Adding a destination is a one-line change to `drawer_destinations.dart`. Prove it
      by adding Counter Stock behind a flag and removing it again.

## Notes

- **The redirects are the whole risk in this release.** 30 hardcoded `/profile` strings,
  four of them parameterised. Everything else here is additive or cosmetic; this is the
  part that silently breaks a deep link and is not noticed for a week. It gets the test.
- **`drawer_destinations.dart` is the point of the release.** The reason navigation
  needed restructuring is that adding a destination previously meant editing a
  hardcoded tuple array, a hardcoded `_topLevelPaths` set, and a hand-written settings
  list. Six more destinations arrive in docs 11, 12, 15 and 16. If they each still cost
  three edits, this release did not fix anything.
- **This is where the role becomes visible**, which is why doc 14's gating is written
  now and left inert. Doc 14's own success criterion — "no screen file changed as part
  of the DAO port" — depends on it.
