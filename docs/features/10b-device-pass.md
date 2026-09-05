# 10b — Device pass

| | |
|---|---|
| **Target version** | `1.11.0+15` |
| **Type** | Fixes + owner-requested changes, on the 10b release |
| **Schema** | No change |
| **Branch** | `release/1.11.0-navigation` |
| **Requires** | [10b — Navigation](10b-navigation.md), built |
| **Ships before** | [10c — Screen restyle](10c-screen-restyle.md) |
| **Status** | Planned — 2026-09-05 |

## Why

[10b](10b-navigation.md) is built and says its device pass is still open. This is that
pass. The owner ran the branch on the phone on 2026-09-05 and came back with 30-odd
points. They split three ways:

1. **Defects.** Five things are wrong, not merely plain. Two of them are dead features.
2. **Global look.** Corner radius, font, background art.
3. **Screen changes the owner asked for.** Layout, controls and one rename.

Everything the owner raised that [10c](10c-screen-restyle.md) already owns is **left to
10c** and listed in *Deferred to 10c* at the end. Nothing is planned twice.

**The version bumps to `1.11.0+15` as the last commit on this branch**, per the roadmap.
That has not happened yet and must not happen before this doc's success criteria pass.

---

## A — Defects

### A1 · Back from order entry lands on the Dashboard

`order_entry_screen.dart:261` and `:289` both call `context.go('/')`. That is a
hardcoded jump to the Overview, not a back. Open Orders → a shop → back, and you are on
the Dashboard, having lost the tab you came from.

- [ ] Replace both with `context.pop()`, guarded by `canPop()` so a deep link into
      `/order/5` still has somewhere to go — fall back to `AppRoutes.orders`, which is
      the screen this one is opened from, not `/`.
- [ ] The loading branch at `:261` has the same bug and the same fix. Do not fix only
      the one you can see.
- [ ] `routing_test.dart` gets a case: push `/order/1` over the Orders branch, pop,
      expect `/orders`.

**This is a rule violation as well as a bug.** AGENTS.md rule 10 says use `AppRoutes`
and never write a route string; `'/'` is a route string.

### A2 · The day-of-week heatmap is always empty

```sql
CAST(strftime('%w', o.order_date) AS INTEGER) AS weekday
```

`dashboard_dao.dart:257`. Drift stores `DateTimeColumn` as **Unix epoch seconds**, an
integer. Given a number, `strftime` reads it as a Julian day, and `1757…` is out of
range, so it returns `NULL` for every row. `r.read<int>('weekday')` then throws on the
null, the provider goes to `AsyncError`, and `weekday_heatmap.dart` renders
`error: (_, _) => _emptyState()`. The card says "not enough data" for a database error.
It has never worked with real data.

- [ ] Add the modifier: `strftime('%w', o.order_date, 'unixepoch')`.
- [ ] Group the inner query on the same expression it selects, so a day is a day and not
      an epoch second.
- [ ] Grep the DAOs for any other bare `strftime` on a `DateTimeColumn`. There is one
      today; there must be none after.
- [ ] `_emptyState()` stops covering for errors. Empty and failed must look different —
      that is [10c](10c-screen-restyle.md)'s Phase 3 rule, applied here early because
      this card is the reason the rule exists.
- [ ] A DAO test with three weeks of seeded orders that asserts a non-empty map. Without
      it this silently breaks again on the Supabase port.

### A3 · Filter pill text is cut in half

`filter_chip_row.dart` fixes the row at `height: 40`, and the chip label is
`AppType.label` — 12px at `height: 1.2`. Product chips prepend a category emoji, and an
emoji glyph is taller than a 1.2 line box, so the row clips it and the text with it.

- [ ] Let the chip size itself and give the row `44` with the chip vertically centred,
      rather than stretching the chip to a fixed box.
- [ ] Drop the tight line height on the chip label only. Do not change `AppType.label`
      globally — it is correct everywhere else.
- [ ] Check the same pattern on any other row that puts an emoji in a `caption` or
      `label` step.

### A4 · The background art is missing on most screens

`AppBackground` is painted once, in `AppShell`. Only the five shell branches get it.
Every pushed screen — order entry, the shop ledger, the masters, the price matrix,
settings — draws on flat cream. And where the shell *does* paint it, `MasterListPage`
and `SettingsScreen` pass `background: AppColors.bg`, an opaque colour that covers it
again. So the art appears on some screens, half-appears on others, and is absent from
the rest. That is the inconsistency the owner saw.

The owner is choosing a new image. This item is about **where it is painted**, not which
image it is.

- [ ] Move the background one level up, to a single widget wrapping
      `MaterialApp.router`'s `builder`, so it is painted once for the whole app and every
      route — shell or pushed — sits on it.
- [ ] `AppScaffold.background` defaults to transparent already. Remove the two
      `AppColors.bg` overrides that defeat it.
- [ ] Keep the existing performance decisions in `app_background.dart` verbatim: no
      `ImageFiltered`, no `Opacity`, blur and alpha baked into the asset, one
      `RepaintBoundary`, `cacheWidth: 360`. Painting it higher up means it is built
      **once for the process** instead of once per shell rebuild, which is strictly
      better than today.
- [ ] Precache the asset in the bootstrap gate so the first frame does not pop.
- [ ] When the new art lands, regenerate the blurred asset with `tool/blur_background.py`
      and commit both. Never blur at runtime.

### A5 · The drawer button sits too far left

The Dashboard, Orders and Billing headers are hand-rolled: a `Padding` of 16 then an
`IconButton`, which adds its own 8 and a 48px minimum tap target. The hamburger reads as
floating in a gutter, and the title beside it does not line up with the content below.

- [ ] Give `AppScaffold`'s header an 8px left gutter when `leading` is an icon button, so
      the **icon** lands on the 16px grid rather than the button box.
- [ ] Point the three hand-rolled headers at `AppScaffold`. 10c migrates every screen;
      these three are migrated now because the alignment cannot be fixed without it.
- [ ] Keep the 48px tap target. This is a padding change, not a size change.

---

## B — Global look

### B1 · Less rounded

Reduce the radius tokens. Do not remove them, and do not touch `rFull` — the nav bar,
avatars and status badges are meant to be capsules.

| Token | Now | After | Used by |
|---|---|---|---|
| `rS` | 10 | **6** | chips, fields, buttons |
| `rM` | 16 | **10** | cards, rows, inputs |
| `rL` | 24 | **14** | hero cards, bottom sheets |
| `rFull` | 999 | 999 | pills, avatars — unchanged |

- [ ] Change the four values in `tokens.dart` and nothing else. Every kit component
      already reads them.
- [ ] The screens that still hardcode `BorderRadius.circular(8|12|16)` will not follow.
      That is 10c's ratchet and stays 10c's. Expect a visible mismatch on unmigrated
      screens until then, and say so out loud rather than half-migrating.

### B2 · Bricolage Grotesque replaces Raleway

- [ ] Vendor the static weights into `assets/fonts/`: Regular 400, Medium 500, SemiBold
      600, Bold 700 — the same four Raleway ships, so no `TextStyle` changes weight.
      Bricolage Grotesque is OFL and available from the Google Fonts repository.
- [ ] Take the **static instances**, not the variable font. Flutter can load a variable
      font but the four `weight:` entries in `pubspec.yaml` are what the theme resolves
      against, and a partial variable-axis setup is how a font silently falls back to
      Roboto on one device.
- [ ] `AppType._family` and `ThemeData.fontFamily` are the only two places the name
      appears. Change both in one commit.
- [ ] **Re-check sizes after the swap.** The roadmap already carries this risk for
      Raleway: it has a smaller x-height than Quicksand, so every size reads light.
      Bricolage Grotesque has a *larger* x-height than both. Expect the app to read
      heavier, not lighter. Do not chase it with size changes here — note the figures and
      let 10c, which touches all 198 of them, do it once.
- [ ] Delete the four Raleway files in the same commit. Two font families in the bundle
      is 400 KB nobody asked for.

---

## C — Dashboard

### C1 · Bring the greeting back

Commit `ddd08d8` deleted it, for a good reason badly applied: the name came from
`const _greetingNames = ['Mohan', 'JMR']` picked by `Random()` at library load. That is
business identity hardcoded in a widget file, which AGENTS.md rule 6 forbids. The
greeting itself was never the problem.

- [ ] Restore `Good morning / Good afternoon / Good evening` above the screen title, in
      the header's caption slot.
- [ ] Take the name from **Business Info** (`businessInfoProvider`), falling back to
      `BrandConfig.appName`. No literal names in `lib/`.
- [ ] Read the hour through `package:clock`, per AGENTS.md rule 14, so the rollover is
      testable.
- [ ] The title stays `Business Overview`. The greeting is the caption above it, not a
      replacement for it.

---

## D — Orders list

### D1 · Two-line row

The owner's sketch:

```
| (avatar)  Shop Title   (status)                    ₹ amount |
| (avatar)  Location                                    N items |
```

One row, two lines, avatar spanning both, money in a straight right-hand column.

- [ ] Left: the letter avatar, vertically centred across both lines.
- [ ] Line 1: shop name, then the status mark (D2), then the amount, right-aligned.
- [ ] Line 2: area on the left, item count on the right.
- [ ] Amount and item count share one right-hand column so figures line up down the
      list. This is the decision commit `762be58` recorded for the ledger; it applies
      here for the same reason.
- [ ] No order yet → line 2 reads `Tap to add order` and the right column is empty. Never
      `₹0`, which reads as a real zero-rupee order.

**Collision note.** 10c already replaces `ShopOrderCard` with `ListRow` on this screen.
This item is the layout `ListRow` should produce; do it here and 10c's Home item is done.
Amend 10c when it lands.

### D2 · Sticker marks, not pills

- [ ] Confirmed → a filled green check. Pending → a filled amber warning.
- [ ] Use the icon font, not PNG stickers. PNGs mean four assets per state per density,
      they do not take a theme colour, and the app already carries an icon set. If the
      owner wants illustrated stickers later, that is an asset swap behind the same
      widget.
- [ ] Add an `icon`-only mode to `StatusBadge` rather than a new widget. It already
      takes an `icon` and an `AppTone`; it needs to be able to drop the label.
- [ ] Keep the label as the semantic name for screen readers. A bare tick is meaningless
      to TalkBack.

---

## E — Order entry

### E1 · Drop "Order Type", and what goes in its place

The info card is two columns: `Order Date` and `Order Type: Regular Order`. The second is
a hardcoded string. There is one order type. It has never told the owner anything.

- [ ] Remove the Order Type column and the `VerticalDivider`.

**What to put there instead.** Ranked, from what the screen can already answer:

| | What it says | Why it earns the slot | Cost |
|---|---|---|---|
| **1** | **Last order** — `3 Sep · 47 items · ₹2,150` | This is the number the quantities get anchored to. Today the owner opens the shop and guesses, or backs out to Billing to look it up | One DAO read, additive |
| **2** | **Owes** — `₹4,320 · 12 days` | The other thing you want in front of you while a shopkeeper is standing there. `watchOutstandingByShop` already exists | Free — the query is shipped |
| 3 | **Standing order** — `Set · 24 items` or `Not set` | Says whether the ⋮ *Load standing order* action will do anything before you tap it | Free — already read on this screen |
| 4 | **Priced** — `26 of 28 priced` | Duplicates the orange banner below it | Free |

**Recommendation: 1 in the freed column, 2 as a small badge beside the shop name in the
header.** They answer different questions — one is about this order, the other is about
this shop — and putting a debt figure inside a card labelled *Order Date* mixes them.
3 belongs in the ⋮ menu label, not in a card. 4 already has a home.

### E2 · Search and category filter under the Order Date card

28 products, one flat alphabetical list, at 5 a.m.

- [ ] `AppSearchField` directly under the info card, matching product name.
- [ ] `FilterChipRow` of categories beneath it — `All`, then the active categories, in
      the same order as the products master, so the two screens agree.
- [ ] **Filtering must never touch a quantity.** A hidden row keeps its value, and the
      sticky total keeps counting it. Verify with a test: set a quantity, filter it out,
      confirm, expect the quantity saved.
- [ ] Clearing the search restores the full list at the same scroll position.
- [ ] Fix A3 before this ships or the category chips clip here too.

### E3 · Steppers lose their background

`_StepperBtn` draws a 36×36 filled brown box behind each icon. Two of them per row, 28
rows, is 56 brown boxes on the busiest screen in the app.

- [ ] Icon only. Keep the 36×36 tap target, drop the `BoxDecoration` fill.
- [ ] Keep the press scale animation and the 400 ms long-press repeat from
      [doc 08](08-order-entry-swipe.md). Those are the feel; the box is not.
- [ ] Disabled stays visibly disabled — `textTertiary`, not an invisible target.

### E4 · The whole row opens the quantity sheet

Today only the 40px number between the steppers is tappable.

- [ ] Wrap the row in the `InkWell`, minus the two stepper hit boxes.
- [ ] The steppers keep working in place. A tap on `+` must not also open the sheet.
- [ ] An unpriced product opens nothing, as now.

### E5 · Bigger wheels

`itemExtent: 40`, `width: 56`, box `height: 120`. Three digits in a 168px-wide cluster
is a thumb-width target for a swipe.

- [ ] `itemExtent` 40 → **48**. Wheel width 56 → **72**. Box height 120 → **200**, which
      shows two neighbours above and below instead of one.
- [ ] Add the iOS selection overlay — a tinted band across the middle row — so the
      selected digit reads as selected. `CupertinoPicker` takes one.
- [ ] Digit size 22 → 28, weight unchanged.
- [ ] Keep the per-notch haptic. It is why the wheel feels like anything at all.

### E6 · `0` is a placeholder, not a value

`_ctrl = TextEditingController(text: widget.initialQty.toString())` seeds `"0"`, so the
owner types `5` into a field containing `0` and gets `50` or `05` depending on where the
caret sits.

- [ ] Seed the controller **empty** when the quantity is 0.
- [ ] `hintText: '0'` for the ghost.
- [ ] Empty on confirm means 0. It does not mean "leave unchanged".
- [ ] A non-zero quantity still seeds its real value, selected, so typing replaces it.

### E7 · Three-dot menu in the header

`Load Standing Order` is a text button in `AppBar.actions`, competing with the shop name
for width.

- [ ] One `PopupMenuButton` with two items:
      - **Load standing order** — the existing action, existing confirm dialog.
      - **Clear all quantities** — new. Sets every quantity to 0.
- [ ] Clear goes through `confirmDestructive`, per AGENTS.md rule 16. Never hand-roll it.
- [ ] Clear writes through the same debounced save path. It is not a special case.
- [ ] Clearing a confirmed order un-confirms it, exactly as editing a quantity does.
- [ ] Label *Load standing order* with its state — `Load standing order (24 items)`, or
      disabled with `No standing order set` — so the menu answers E1's item 3.

---

## F — Kitchen

### F1 · Drop the unit line under By Item

`ListTile(subtitle: unit != null ? Text('per $unit') : null)`. "per pc" under every row,
on the screen that exists to be read across a kitchen.

- [ ] Remove the subtitle. The quantity column already carries the meaning.
- [ ] Match By Shop's row shape, which has no second line.

### F2 · By Item groups by category

By Shop groups by shop. By Item is a flat list, and the bake order is by category.

- [ ] Group by `categoryId`, using the same category sort order as the share text
      already does in `_shareItems`. That grouping logic exists; reuse it rather than
      writing a second one that can disagree.
- [ ] Uncategorised products fall into an **Others** group, last.
- [ ] Category header carries the emoji and the group's total quantity.
- [ ] The share text and the screen must produce the same grouping. One function, two
      renderers.

---

## G — Billing

### G1 · Three-row bill card

The owner's sketch, with the clarification that it is **three rows, clearly separated,
money on the right**:

```
| (n)  Shop Title   (status)                       ₹ big total |
|      Location                                       amount   |
| ------------------------------------------------------------ |
| (order status)  (payment status)              [ share ]      |
```

- [ ] Rows 1 and 2 are the shop and its money. Row 3 is a separated action strip: the
      two status pills on the left, share on the right.
- [ ] A hairline divider between row 2 and row 3. "Clear separation" is the point.
- [ ] Money right-aligned in one column, as D1.
- [ ] **Keep both existing gestures unchanged**: long-press records a payment, tap
      expands the line items, `_expandedOrderId` behaviour identical.
- [ ] The share icon moves out of the crowded trailing cluster into row 3, which is what
      the `FittedBox` scale-down hack at `orders_screen.dart:396` was working around.
      Delete the hack with it.

### G2 · "Share bills", with a picker

- [ ] Rename `Share All Bills` → **Share bills**.
- [ ] On tap, open a shop multi-select sheet. All selected by default — the common case
      is still all of them.
- [ ] Share the selected shops only, and total only those. A partial share whose
      GRAND TOTAL is the full day's figure is a wrong number sent to a customer.
- [ ] Reuse `catalog_share_picker_screen.dart`'s selection shape if it fits. Do not write
      a second multi-select.

---

## H — Ledger, was Finances

### H1 · Rename

- [ ] `Finances` → **Ledger**, in `destinations.dart` and nowhere else. Rule 12.
- [ ] Keep the route `/finances`. A path rename buys nothing and costs a redirect rule.
- [ ] **Watch the collision.** There is already a per-shop *Shop Ledger* at
      `/shops/:id/ledger`, in `lib/screens/ledger/`, and `ledger` is already a search
      keyword on this destination. After the rename the drawer says Ledger and a shop row
      opens something also called Ledger. Distinguish them in the UI: this one is
      **Ledger**, that one is **`<Shop name>` statement** — its header already shows the
      shop name, so the change is the word under it.
- [ ] Do not rename the files. `finances_screen.dart` staying put is a smaller diff than
      a rename nobody can grep for later.

### H2 · Period filter, defaulting to All time

The screen is fixed at 30 days, deliberately, per its own doc comment. The owner has
overruled that. Record it rather than silently deleting the comment.

- [ ] Reuse `DateRangePill` from the dashboard. Do not write a second range control.
- [ ] Add an **All time** option; make it the default here. The dashboard's default does
      not change.
- [ ] The filter drives the summary band and the outstanding figure.
- [ ] **Outstanding is a balance, not a period figure.** "What is owed to me as of today"
      does not change because you asked about last week. Filter the *billed / collected /
      net* band; leave the hero total as the live balance and label it so.

### H3 · Fold the caption into the stat card

`SectionHeader(title: 'Last 30 days', caption: 'Billed against collected')` draws the
caption in `textTertiary` over the background art. It is not readable.

- [ ] Move `billed · collected · net` into the stat card itself, labelled in place.
- [ ] Delete the separate caption row. The labels under each figure say it better than a
      heading above three of them.
- [ ] Check the same pattern anywhere else a tertiary caption sits directly on the
      background.

### H4 · Sort "Who owes"

- [ ] A sort control on the section header: **by amount** (default, as now) and
      **by name**.
- [ ] Sort in the screen, not in a new query. 18 rows.
- [ ] The choice does not need to persist across launches.

---

## I — Masters

### I1 · Shops row

- [ ] `Ledger` moves out of the footer to the **right of the row, vertically centred**.
- [ ] `Deactivate` / `Activate` moves into a ⋮ menu on the same right edge.
- [ ] The footer row disappears with them, so the row loses a line.
- [ ] Deactivate keeps its confirm. It is destructive to a shop's history.

### I2 · Products row

- [ ] `Deactivate` / `Activate` into a ⋮ menu, as I1. The footer goes.
- [ ] Subtitle carries **price · unit · category**: `₹22 · pc · 🥐 Puffs`.
- [ ] The price is the product's own default price, not a per-shop price. Say `Price not
      set` when it is null rather than leaving a gap. Per-shop prices are the price
      matrix's job and must not be implied here.

### I3 · Search on Standing Orders and Price Matrix

Both screens list every product for a chosen shop, unsearchable.

- [ ] `AppSearchField` above the product list on each, matching name.
- [ ] **Filtering must not drop an edit.** Both hold a `Map<int, TextEditingController>`
      built per shop; filtering must hide rows, never rebuild or dispose the controllers,
      or a typed price vanishes when you clear the search.
- [ ] Save still writes every controller, not just the visible ones.

**Collision note.** 10c rebuilds the price matrix on `ListView.builder` with a sticky
column. The search box is additive and independent of that. Keep them separate.

---

## J — Navigation and motion

### J1 · The bottom bar hides on scroll down

- [ ] Hide on scroll down, show on scroll up, show at rest.
- [ ] **This means moving the bar out of `Scaffold.bottomNavigationBar`.** That slot
      insets the body, so animating the bar's height reflows every screen on every
      frame. It goes into `AppShell`'s existing `Stack` as a bottom-positioned overlay
      with a slide transition — which is also where `app_shell.dart`'s own comment says
      the background had to go, for the same reason.
- [ ] Every shell screen then needs bottom padding of its own. Most already carry
      `bottom: 96` or `100`; make it one constant instead of four guesses.
- [ ] Respect `MediaQuery.disableAnimations` — no slide, bar always visible.
- [ ] **This is the riskiest item in this doc.** It changes the layout contract of all
      five branch screens. Land it on its own commit, after everything else, so it can be
      reverted without taking the rest with it.

### J2 · Relative date labels

`DateSelector` shows `05 Sep 2026, Fri` and nothing else, on Orders, Kitchen and Billing.

- [ ] One `relativeDayLabel(DateTime, {required DateTime today})` in `lib/utils/`, pure,
      unit-tested, used by all three screens. Never three copies.
- [ ] The ladder:
      | Distance | Label |
      |---|---|
      | 0 | `Today` |
      | +1 / −1 | `Tomorrow` / `Yesterday` |
      | same calendar week | `This Mon` … `This Sun` |
      | next / previous calendar week | `Next Tue` / `Last Tue` |
      | anything else | `12 Sep`, with the year when it is not this year |
- [ ] **Keep the full date visible underneath, small.** A bill for "Next Tue" is a bill
      whose actual date the owner still needs to read.
- [ ] Weeks are Monday-start, matching the heatmap's day labels.
- [ ] Read today through `todayProvider`, so the label re-derives at midnight along with
      everything else.

> **Assumption to confirm.** The owner's list says "fortnite". Read as *fortnight*, and
> covered by the `Next` / `Last` week rows above — a fortnight is not a day, so it cannot
> be a label on a single-day selector. If something else was meant, say so.

### J3 · Scroll to top on screen change

`StatefulShellRoute.indexedStack` preserves each branch's scroll position by design,
which is right for a back press and wrong for a tab switch.

- [ ] When a branch becomes visible, jump its primary scroll view to 0.
- [ ] Jump, do not animate. An animated scroll on a screen you are already looking at
      reads as a glitch.
- [ ] Tapping the current tab already resets it via `goBranch(initialLocation: true)`.
      Do not add a second mechanism that fights it.
- [ ] A back press returning to a branch keeps its position. Only a switch resets.

### J4 · Catalogue returns to Settings

`settings_screen.dart` carries a long comment explaining why the masters are *not*
listed there, and 10b's own build notes say the opposite ("the owner chose both"). The
code won. The owner has now chosen both again.

- [ ] A **Catalogue** card in Settings: Shops, Products, Categories, Price Matrix.
- [ ] Build it from `destinationsIn(DestGroup.catalogue)` plus the Price Matrix, not from
      a hand-written list. Rule 12: a destination is added in `destinations.dart` and
      nowhere else.
- [ ] Each row gets a live summary, like every other Settings row —
      `18 active · 2 inactive`, `212 of 504 prices set`. The aggregates exist already on
      `catalogueCoverageProvider`.
- [ ] Delete the comment that says they are not there, and fix 10b's build note. A doc
      that describes the opposite of the code is worse than no doc.

---

## Deferred to 10c

Raised by the owner, already owned by [10c](10c-screen-restyle.md), **not planned here**:

| Owner's point | Where it lives |
|---|---|
| Rows too tall and card-heavy across the app | 10c *Dense scannable rows* |
| Billing grand total below the fold | 10c *Billing → `StatBand`* |
| Grey icon + one grey line empty states | 10c *Empty states with an action* |
| `Error: <exception>` on screen | 10c Phase 3, `AppErrorView` |
| Hand-rolled headers on every screen | 10c *`AppScaffold`* (A5 pulls three forward) |
| Hardcoded radii not following B1 | 10c *Closing the ratchet* |
| Price matrix slow with 504 cells | 10c *`price_matrix_screen.dart`* |
| Every quantity tap rebuilds 28 rows | 10c *Order entry — the rebuild fix* |

**Three items in this doc touch files 10c rewrites** — D1 (Orders rows), G1 (Billing
card), I1/I2 (master rows). They are here because they are layout decisions the owner
made from the phone, and 10c would otherwise re-derive them from a mockup. Amend 10c's
action list as each lands, so it does not build them twice.

---

## Success criteria

- [ ] Orders → a shop → back returns to **Orders**. Not the Dashboard.
- [ ] The heatmap renders bars with 30 days of seeded data, and shows a **distinct**
      failure state when its query fails.
- [ ] No category chip clips its emoji, on Products or on Order entry.
- [ ] Every screen in the app, shell or pushed, shows the background art. Verified by
      opening all 23 routes.
- [ ] Bricolage Grotesque renders on device. No Roboto fallback on any weight.
- [ ] No Raleway file remains in `assets/fonts/`.
- [ ] Order entry: filter to one category, set a quantity, clear the filter, confirm —
      the quantity is saved.
- [ ] The quantity input opens **empty** with a ghost `0` at quantity 0.
- [ ] Share bills with three of eighteen shops selected produces a total of those three.
- [ ] The Ledger period filter defaults to All time; the outstanding hero does not change
      when the period changes.
- [ ] `flutter test` green, `flutter analyze` clean.
- [ ] `./tool/check_tokens.sh` count is **not higher** than 354. It may rise from new
      code; it must not, so write new code on the kit.
- [ ] `pubspec.yaml` bumped to `1.11.0+15` as the **last** commit on this branch.
- [ ] The five 10b criteria that still need the phone are walked and ticked in
      [10b](10b-navigation.md)'s *What still needs the phone* table.
- [ ] A backup exported from `1.10.0+14` restores into this build. Readiness gate step 7,
      the one that gets skipped.

## Order of work

1. **A1, A2, A3** — three defects, three small commits, independently revertable.
2. **B1, B2** — the two global swaps. Everything after this sees the new radius and font.
3. **A4, A5** — background and header, which move shared widgets.
4. **C, E, F, G, H, I** — screen by screen, one commit each.
5. **J2, J3, J4** — additive.
6. **J1** — last, alone. It changes the layout contract of all five branch screens.

D1 rides with E, since both touch the Orders flow and the owner reads them together.
