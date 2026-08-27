# App audit — Milano Orders `1.7.0+9`

> Written 2026-08-26, against commit `762be58`, schema v6.
> This is the **current-state record** that the UI overhaul block
> ([10](features/10-ui-overhaul.md), [10a](features/10a-design-system.md),
> [10b](features/10b-navigation.md), [10c](features/10c-screen-restyle.md)) is built from.
> It describes what is, not what should be. Read it once; the plans carry the decisions.

---

## 1. What this app became

It started as a way to write down what the kitchen has to bake tomorrow. It is now
the operating system of a small distribution business.

| Module | Shipped in | What it does |
|---|---|---|
| Daily orders | v1.0 | Per-shop order entry against a date, standing-order prefill |
| Kitchen list | v1.0 | Aggregated production list, item-wise and shop-wise, shareable |
| Billing | v1.2 | Per-shop day bills, grand total, confirm flow |
| Shops · Products · Categories | v1.0–v1.4 | Masters |
| Price matrix | v1.2 | Per-shop, per-product price overrides |
| Standing orders | v1.2 | Default quantities per shop |
| Catalogue sharing | v1.4 | Menu-card PDF export and share |
| Business info | v1.2 | Name, contact, logo used in shared documents |
| Dashboard | v1.5 | 7 analytical cards, configurable, date-ranged |
| Backup & restore | v1.3 | Full JSON export/import |
| In-app update | v1.6 | GitHub Releases check + download |
| Ledger | v1.7 | Payments, FIFO allocation, per-shop statement, outstanding |

Twelve modules. **22 routes. 12,029 lines of Dart across 77 files.** Six test files,
1,431 lines, correctly concentrated on the things that carry money.

The engineering underneath is genuinely good, and this audit should not be read as
saying otherwise. Drift with a real migration chain and a v4→v6 upgrade path; DAOs
that keep SQL out of the UI; Riverpod providers with stable signatures the Supabase
port can slide under; a signed-APK release pipeline; FIFO allocation with a
1-paisa epsilon and tests that actually prove it. That foundation is why a redesign is
worth doing — there is something solid to redesign.

**What did not keep up is everything above the DAO line.** Twelve modules were added
one at a time, each shipped in the shape that was convenient that week, and nothing
ever went back to arrange them into a whole. That is the entire problem, and it shows
up in three places: where things live, how they look, and how fast they feel.

---

## 2. Where things live — the structural problem

### 2.1 The route inventory

22 routes. **15 of them — 68% — sit behind `/profile`.**

```
/splash
/                              home · shops for the selected date
/orders                        daily billing
/kitchen                       production list
/dashboard                     pushed from the FAB, outside the shell
/order/:shopId                 order entry
/profile                       ← 15 routes live behind this one tab
   /shops · /shops/new · /shops/:id/edit · /shops/:id/ledger
   /products · /products/new · /products/:id/edit · /products/share
   /prices
   /standing-orders
   /business-info
   /categories
   /backup
   /dashboard-settings · /dashboard-settings/help
```

Read that list back as a person rather than a router. `/profile` currently contains:
five masters, a price matrix, a document generator, a data-safety tool, a
customisation panel, a version checker — **and the shop ledger**, the newest and most
financially important screen in the app.

There is no organising idea there. It is a drawer that everything gets put in
because there is nowhere else to put it. The name is the giveaway: a tab called
"Profile" that contains no profile.

### 2.2 The ledger is buried four taps deep

The ledger shipped last week. It answers "who owes me money" — arguably the highest-value
question the app can answer. Its route is `/profile/shops/:id/ledger`.

To reach it: **Profile → Shops → find the shop in a list → row menu → View Ledger.**
Four taps and a visual scan, from a tab named after something else. Outstanding
receivables — the number in reference image 3's hero card — has no home at all in the
current app. You can only get it one shop at a time.

### 2.3 The bottom bar spends its slots badly

Four slots: Home · Billing · Kitchen · Profile. Three are daily jobs. The fourth is
a filing cabinet, and it is given exactly the same prominence as the work.

The FAB opens the Dashboard as a **top-level push route outside the shell** — so the
dashboard has no bottom bar, no way back except system back, and returning drops you
wherever you were. There is a related dead line in `lib/app.dart`: `_topLevelPaths`
includes `'/dashboard'`, but that set is only ever read inside `_ScaffoldWithNavBar`,
which the dashboard route never builds. The entry has never done anything.

### 2.4 Depth, counted

| Destination | Taps from home today |
|---|---|
| Order entry for a shop | 1 |
| Kitchen list | 1 |
| Billing | 1 |
| Dashboard | 1 (FAB) |
| Any master (shops, products, categories…) | 2 |
| Price matrix | 2 |
| Shop ledger | **4** + scan |
| A specific product's price for a specific shop | **3** + two scans |
| Outstanding across all shops | **not reachable** |

By the time docs 06–13 land there are roughly 28 destinations. A four-slot bar and a
flat 9-item list do not address 28 destinations. This is exactly what
[doc 10](features/10-ui-overhaul.md) was opened for on 2026-08-19, and it has only got
more true since.

---

## 3. Why it looks basic

Not a taste problem. A **systems** problem: there is no design system, so every screen
re-invents the same decisions slightly differently, and the eye reads the inconsistency
as "unfinished" long before it reads any individual screen as ugly.

### 3.1 The numbers

Measured across `lib/`:

| Signal | Count | What it means |
|---|---|---|
| `fontSize:` literals | **14 distinct values** (8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24) | No type scale |
| `Theme.of(context).textTheme` uses | **2**, in 12,029 lines | The theme's typography is effectively unused |
| `FontWeight` values in play | **6** (w400–w800, plus `bold`) | `bold` and `w700` both used, interchangeably |
| `Colors.grey.shadeNNN` / `Colors.grey[NNN]` | **111** | No neutral ramp; grey is picked per call site |
| `BorderRadius.circular(n)` | **8 distinct radii** (4, 6, 8, 10, 12, 16, 20, 32) | No radius scale |
| `EdgeInsets` literals | **117** | No spacing scale |
| `withAlpha(n)` for tints | 4 distinct values (20, 30, 40, 80) | Elevation/tint by eyeball |
| `RepaintBoundary` | **0** | No paint isolation anywhere |

Four brand constants exist (`kBrandGold`, `kBrandBrown`, `kBrandMaroon`, `kSurface`) and
they are the only tokens in the codebase. Everything else — every grey, every size,
every gap, every corner — is a literal typed at the call site.

### 3.2 Two competing header idioms

Five screens hand-roll an identical header: `Padding(16,16,16,8)` → `Row` → gold icon
at size 28–30 → `Column` with an 11px letter-spaced grey caption over a 22px
`w800` brown title.

```
WELCOME BACK            DAILY BILLING           KITCHEN
Good morning, Raja      Shop Bills              Production
```

It is copy-pasted five times in `home_shops_screen`, `orders_screen`,
`kitchen_screen`, `dashboard_screen` and `profile_screen`. Meanwhile **15 other
screens use a real `AppBar`.** So the app has two headers that look nothing alike, and
which one you get depends on whether the screen was written before or after the v1.3
restyle. There is no shared header widget to have used.

### 3.3 Whitespace without hierarchy

The layout instinct is right — cream ground, white cards, breathing room. What is
missing is **density where density is the point.**

- `ShopOrderCard` spends a full 16px-padded card, an avatar, a title, an area row and
  a chip row on what is, for a shop with no order yet, the single word "Tap to add
  order". Eighteen shops means eighteen of those, and the screen that answers "which
  shops still need an order today" makes you scroll to answer it.
- The billing list has no summary band, so the grand total is computed
  (`summaries.fold`) and then shown below the fold.
- The dashboard is one continuous scroll of seven cards with no tabs, which
  [doc 12](features/12-dashboard-tabs.md) already flags as unreadable once ledger and
  stock cards join it.
- Empty states are a grey icon at size 64 and one line of grey text. There is no
  action offered, so the correct next step is left for the user to infer.

The reference screens do the opposite in every one of these cases: a stat band before
the list, dense scannable rows, an action in the empty state, and colour used to carry
meaning rather than decoration.

### 3.4 Colour carries almost no meaning

Gold and brown are used for *everything* — headers, chips, buttons, avatars, arrows,
icons. Semantic colour barely exists: green/red appear only in the ledger's Dr/Cr
amounts and a couple of dashboard deltas, and they are raw `Colors.green` /
`Colors.red` rather than tokens.

Reference image 3 is the counter-example, and it is instructive: a dark brown hero
card, a red/amber/green risk donut, red overdue figures, a green highlighted forecast
bar, green delta text. **Every colour there means something.** That is what the app
is currently missing, and it costs nothing to fix beyond deciding it once.

### 3.5 The good news, stated plainly

Comparing the reference screens against `lib/app.dart`:

| Reference | Existing constant | Verdict |
|---|---|---|
| Cream page ground | `kSurface = #FFFBF5` | **Already exact** |
| Espresso brown surfaces, sidebar, primary buttons | `kBrandBrown = #4A2C2A` | **Already right**, needs a darker step for the sidebar/hero |
| Gold FAB, primary CTA, active chip fill | `kBrandGold = #FFC000` | **Already exact** |
| Letter avatars per shop | `LetterAvatar` exists | Already built |
| White cards, soft shadow, generous radius | Cards at radius 12 | Right idea, needs a bigger radius and a softer shadow |

**This is not a rebrand.** The palette in the reference screens is the palette already
in the code. What the references add is *system* — a type scale, a spacing scale,
semantic colour, and a set of repeatable compositions (stat band, filter chip row,
section header with a "View all", expandable card, hero card). The gap is
organisation, not identity.

---

## 4. Why it feels slow

Five specific causes, ranked by how much they cost against how hard they are to
remove. None of them is the database.

### 4.1 A blurred full-screen PNG behind every screen — every frame

`lib/widgets/app_background.dart` is painted into a `Stack` beneath every shell screen:

```dart
Opacity(
  opacity: 0.5,
  child: ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
    child: Image.asset('bg-vector.png', fit: BoxFit.cover, ...),
```

A 144 KB PNG, decoded at full source resolution, scaled to cover the screen, run
through a **runtime Gaussian blur**, then composited at 50% opacity — with no
`RepaintBoundary` and no cached result. `ImageFiltered` and `Opacity` both force
`saveLayer`. This repaints on every frame that anything above it animates, which
includes every list scroll, every staggered fade-in and every tab change.

This is the single largest rendering cost in the app, it is on **every screen**, and it
is decorative. Pre-blurring the asset at build time and adding a `RepaintBoundary`
removes essentially all of it.

### 4.2 Deliberate animation delay on every list

`StaggeredFadeIn` wraps every row in the home, billing and kitchen lists:

```dart
final delayMs = 30 * widget.index.clamp(0, 12);
Future.delayed(Duration(milliseconds: delayMs), ...)
```

Plus a 250 ms fade. So the **last visible row of an 18-shop list finishes appearing
360 ms after the data is ready**, and the whole list is animating for ~600 ms. Each
row is also a separate `Future.delayed` timer and a `setState` on an individual
`StatefulWidget`.

The data arrives fast. The app then waits, on purpose, before showing it. This reads
as lag because it *is* lag — it is simply intentional.

### 4.3 Cold start pays a 1.2-second animation tax

`splash_screen.dart` runs a fixed 1200 ms `AnimationController` and navigates only on
`AnimationStatus.completed`. There is no work being waited on — the animation *is* the
wait. That sits on top of the native splash, so a cold start is native splash + 1.2 s
before the first real pixel.

The logo it animates, `mobile-app-logo-trasnsp.png`, is **284 KB** decoded at full
resolution to be drawn at 160×160, with no `cacheWidth`.

### 4.4 No provider is `autoDispose` — 35 of 35

```
provider declarations: 35
autoDispose:            0
```

Several are families keyed on values that change constantly:
`orderSummariesForDateProvider(date)`, `kitchenLinesForDateProvider(date)`,
`orderWithLinesProvider(id)`, `pricesForShopProvider(shopId)`,
`shopLedgerProvider(...)`, `shopStatsProvider(shopId)`, `billStatusProvider(orderId)`.

Every distinct argument creates an instance that **lives for the process lifetime**,
each holding an open Drift stream subscription. Step back through fourteen days on the
home screen and you now have fourteen live `watchOrderSummaries` subscriptions, all
re-running on every write. Open eight shops' ledgers and those stay too.

The app therefore gets measurably slower the longer a session runs, and a write costs
more the more of the app you have visited. This is the cause most likely to match the
subjective report of slowness, because it is the one that gets *worse over the day*.

### 4.5 Order entry rebuilds the whole product list on every tap

`order_entry_screen.dart` bypasses the provider layer entirely — `ref.read(databaseProvider)`
plus `.first` on four streams — and holds `_qtys` as a `Map<int,int>` in widget state.
Every quantity change calls `setState`, rebuilding **all 28 product rows** to change one
number, then debounces a 500 ms full `replaceOrderLines` write.

This is the screen used most, at 5 a.m., under time pressure. It is also the screen
[doc 08](features/08-order-entry-swipe.md) is about to add a swipe gesture to, which
makes the per-tap rebuild cost matter considerably more than it does today.

### 4.6 Secondary, worth fixing while nearby

- `ListView(` (eager, builds every child) is used **6 times** against `ListView.builder`
  **4 times**. The price matrix and settings lists build every row up front.
- 63 `Column(` in screen files, several inside scroll views — long scrolls with no
  viewport recycling.
- `dashboard_screen.dart` has a `_refreshDashboard` that invalidates **14 providers**
  by hand. It works, but any provider added later and not added to that list silently
  stops refreshing.

### 4.7 What is *not* slow

Worth stating so effort does not go to the wrong place. [Doc 04](features/04-dashboard-performance.md)
already removed the dashboard's N+1 queries and duplicated aggregates, and
[doc 03](features/03-db-integrity.md) added the indexes on the order/line hot paths.
The DAO layer is in good shape. **Every item above is in the widget layer.**

---

## 5. What the reference screens actually change

The four references are not a skin. They encode five compositional patterns the app
does not currently have, and each one solves a specific problem named above.

1. **Hero stat card** (image 3: dark brown, total outstanding, donut, legend).
   Answers the "what is the state of this whole module" question before any list.
   Fixes §3.3 — the missing summary band on billing, and the un-reachable
   all-shops outstanding from §2.2.

2. **Filter chip row with live counts** (image 2: `All Shops 18 · Needs Review 2 ·
   No Order 1`, active chip in a soft gold fill). Replaces "scroll and scan" as the
   way to narrow a list, and shows the shape of the data before you touch it.

3. **Section header with a `View all` affordance** (image 3: "At Risk Shops · View all",
   "Payment Behaviour Insights · View report"). Lets a summary screen point into a
   detail screen. This is the mechanism that makes a shallow information architecture
   possible at all — a dashboard becomes a set of entry points, not a dead end.

4. **Dense scannable rows** (image 3: avatar · name · area on the left, ₹ amount ·
   `Overdue 12 days` right-aligned in red). Compare with `ShopOrderCard`'s
   16-padded card for one line of text. Same information, roughly half the height,
   and the money forms a straight right-hand column — the same principle commit
   `762be58` already established for the ledger.

5. **Semantic colour with deltas** (image 2: `+₹240` red pill, `−₹120` green pill;
   image 3: red/amber/green risk, green `↑ 8% vs last month`). Fixes §3.4.

Plus the shell itself, image 4: a dark brown side menu with a gold wordmark, grouped
items, the active item in a cream pill, a divider before Settings, and a **pinned
Outstanding card at the bottom** — the module's headline number living permanently in
the navigation. And a five-slot bottom bar with a gold centre FAB.

**Decided with the owner, 2026-08-26:** the side menu is a **mobile drawer only**. The
desktop sidebar in image 4 is a styling reference for that drawer. No rail, no
breakpoint layouts, no desktop build — now or later.

---

## 6. Where this is heading, and what that demands

Three things are already committed and change what "good structure" means:

- **[Doc 14](features/14-supabase-auth.md) — Supabase, auth, three roles.** Owner /
  manager / staff. A staff member sees counter stock and the kitchen list and nothing
  else. **Navigation is where a role becomes visible**, so the drawer has to be built
  role-aware from the start even though the role is hardcoded to `owner` until 14
  ships. Doc 10's original outline already called for exactly this, via a
  `session_provider` returning a constant.

- **Auto suggestions, weekly AI report** ([15](features/15-auto-order-suggestions.md),
  [16](features/16-weekly-ai-report.md)). Both are new top-level destinations, and
  reference image 2 is one of them, already designed. The navigation must have room
  for them without another restructure.

- **White-labelling** ([17](features/17-white-label.md)). Decided 2026-08-26: the
  design system is **built for it now, shipped later.** Brand colour, logo, and app
  name resolve through a single `BrandConfig` from day one, and "Milano" stops being
  hardcoded in UI strings. Doing this at token-definition time costs almost nothing.
  Retrofitting it means touching every screen a second time.

---

## 7. Findings, ranked

| # | Finding | Severity | Where it is fixed |
|---|---|---|---|
| 1 | No design tokens — 14 font sizes, 111 ad-hoc greys, 8 radii, 117 spacing literals | **High** | [10a](features/10a-design-system.md) |
| 2 | 68% of routes behind a tab called "Profile" with no organising idea | **High** | [10b](features/10b-navigation.md) |
| 3 | Blurred full-screen PNG repainting under every screen, every frame | **High** | [10a](features/10a-design-system.md) |
| 4 | 0 of 35 providers `autoDispose` — leaks streams, degrades over a session | **High** | [10a](features/10a-design-system.md) |
| 5 | Ledger 4 taps deep; all-shops outstanding unreachable | **High** | [10b](features/10b-navigation.md) |
| 6 | Two competing header idioms (5 hand-rolled vs 15 `AppBar`) | Medium | [10a](features/10a-design-system.md) → [10c](features/10c-screen-restyle.md) |
| 7 | Deliberate 360 ms stagger + 1.2 s splash gate | Medium | [10a](features/10a-design-system.md) |
| 8 | Order entry rebuilds 28 rows per keystroke, bypasses providers | Medium | [10c](features/10c-screen-restyle.md), before [08](features/08-order-entry-swipe.md) |
| 9 | Colour carries no meaning; no semantic tokens | Medium | [10a](features/10a-design-system.md) |
| 10 | Low-density lists; no summary bands; inert empty states | Medium | [10c](features/10c-screen-restyle.md) |
| 11 | "Milano" hardcoded throughout the UI | Low now, **High at [17](features/17-white-label.md)** | [10a](features/10a-design-system.md) |
| 12 | Dead `'/dashboard'` entry in `_topLevelPaths`; 14 hand-listed invalidations | Low | [10b](features/10b-navigation.md) |

Nothing in this table is in the database layer. That is the useful conclusion: the
data model, the DAOs and the tests are sound, and **the entire cost of this overhaul
sits above the provider line**, which is also the layer [doc 14](features/14-supabase-auth.md)
promises not to touch. The two pieces of work do not collide.
