# 10b — Device pass

| | |
|---|---|
| **Target version** | `1.11.0+15` |
| **Type** | Fixes + owner-requested changes, on the 10b release |
| **Schema** | No change |
| **Branch** | `release/1.11.0-navigation` |
| **Requires** | [10b — Navigation](10b-navigation.md), built |
| **Ships before** | [10c — Screen restyle](10c-screen-restyle.md) |
| **Status** | A–K built — 2026-09-05 |

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

- [x] Replace both with `context.pop()`, guarded by `canPop()` so a deep link into
      `/order/5` still has somewhere to go — fall back to `AppRoutes.orders`, which is
      the screen this one is opened from, not `/`.
- [x] The loading branch at `:261` has the same bug and the same fix. Do not fix only
      the one you can see.
- [x] `routing_test.dart` gets a case: push `/order/1` over the Orders branch, pop,
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

- [x] ~~Add the modifier: `strftime('%w', o.order_date, 'unixepoch')`.~~
      **Done differently, and better.** `'unixepoch'` fixes the null and leaves a worse
      bug behind: epoch seconds are UTC and these dates are local midnights, so east of
      Greenwich every order counts against the previous day — Monday's bake under
      Sunday. The DAO now returns one row per (category, day), the same shape as
      `getCategorySparklines`, and the provider takes the weekday from
      `DateTime.weekday`. No timezone in the path, and the Sunday-first remap goes with
      it.
- [x] ~~Group the inner query on the same expression it selects.~~ Moot — there is no
      derived expression in the query any more.
- [x] Grep the DAOs for any other bare `strftime` on a `DateTimeColumn`. There is one
      today; there must be none after.
- [x] `_emptyState()` stops covering for errors. Empty and failed must look different —
      that is [10c](10c-screen-restyle.md)'s Phase 3 rule, applied here early because
      this card is the reason the rule exists.
- [x] A DAO test with three weeks of seeded orders that asserts a non-empty map. Without
      it this silently breaks again on the Supabase port.

### A3 · Filter pill text is cut in half

`filter_chip_row.dart` fixes the row at `height: 40` and hands the whole of `padding`
to a **horizontal** `ListView`.

**Corrected once the code was open.** The emoji was the suspect and is not the culprit.
In a horizontal list the vertical half of the scroll view's padding comes off the cross
axis: 40 − 8 − 8 left each chip 24px, the chip's own 8 + 8 left 8px for the text, and a
12px label needs 14.4px. The engine clipped it, top and bottom — exactly "cropped into
half". The tight emoji line box was a second squeeze behind it, and is fixed too.

- [x] Move the vertical half of `padding` outside the box, where it separates the row
      from its neighbours instead of eating it. The horizontal half stays inside the
      scroll view so the first chip starts on the gutter and the last can scroll past.
      Row height `44`.
- [x] Give the chip label its own line height. Do not change `AppType.label` globally —
      it is correct everywhere else.
- [x] Check the same pattern on any other row that puts an emoji in a `caption` or
      `label` step. Two candidates, both fine: the product row's subtitle (`bodyS`,
      17.5px box at 13px) and the category avatar (`titleM`, 21.25px at 17px) each have
      room. Left alone.

### A4 · The background art is missing on most screens

`AppBackground` is painted once, in `AppShell`. Only the five shell branches get it.
Every pushed screen — order entry, the shop ledger, the masters, the price matrix,
settings — draws on flat cream. And where the shell *does* paint it, `MasterListPage`
and `SettingsScreen` pass `background: AppColors.bg`, an opaque colour that covers it
again. So the art appears on some screens, half-appears on others, and is absent from
the rest. That is the inconsistency the owner saw.

The owner is choosing a new image. This item is about **where it is painted**, not which
image it is.

- [x] Move the background one level up, to a single widget wrapping
      `MaterialApp.router`'s `builder`, so it is painted once for the whole app and every
      route — shell or pushed — sits on it.
- [x] `AppScaffold.background` defaults to transparent already. Remove the two
      `AppColors.bg` overrides that defeat it.
- [x] Keep the existing performance decisions in `app_background.dart` verbatim: no
      `ImageFiltered`, no `Opacity`, blur and alpha baked into the asset, one
      `RepaintBoundary`, `cacheWidth: 360`. Painting it higher up means it is built
      **once for the process** instead of once per shell rebuild, which is strictly
      better than today.
- [x] ~~Precache the asset in the bootstrap gate.~~ **Not needed, so not
      added.** The widget now mounts above the router, before the first
      route and behind the native splash, which is already the earliest
      point it could decode. Precaching there would be a second call site
      for no frame.
- [ ] When the new art lands, regenerate the blurred asset with `tool/blur_background.py`
      and commit both. Never blur at runtime. **Open — waiting on the image.**

### A5 · The drawer button sits too far left

The Dashboard, Orders and Billing headers are hand-rolled: a `Padding` of 16 then an
`IconButton`, which adds its own 8 and a 48px minimum tap target. The hamburger reads as
floating in a gutter, and the title beside it does not line up with the content below.

- [x] Take the button's own inset off the header's left gutter when it leads with one,
      so the **glyph** lands on the 16px grid rather than the button box. That is 4px of
      padding, not 8: an `IconButton` is a 48px box around a 24px icon and so carries
      12px of its own.
- [x] Point the three hand-rolled headers at `AppScaffold`. 10c migrates every screen;
      these three are migrated now because the alignment cannot be fixed without it.
- [x] Keep the 48px tap target. This is a padding change, not a size change.

---

## B — Global look

### B1 · Less rounded

Reduce the radius tokens. Do not remove them, and do not touch `rFull` — the nav bar,
avatars and status badges are meant to be capsules.

| Token | Was | Now | Used by |
|---|---|---|---|
| `rS` | 10 | **6** | chips, fields, buttons |
| `rM` | 16 | **10** | cards, rows, inputs |
| `rL` | 24 | **14** | hero cards, bottom sheets |
| `rFull` | 999 | 999 | pills, avatars — unchanged |

- [x] ~~Change the four values in `tokens.dart` and nothing else.~~ Three values, plus
      one thing the plan had wrong: `bottomSheetTheme` carried its **own literal 24** and
      so ignored `rL` entirely. Every sheet in the app — the quantity wheel, record
      payment, the shop picker — would have stayed round while the cards came down.
      `AppRadius.sheetTop` exists now because `bottomSheetTheme` needs a `const` and
      `rL.topLeft` is a property read, not a constant.
- [x] The screens that still hardcode `BorderRadius.circular(8|12|16)` do not follow.
      That is 10c's ratchet and stays 10c's. **53 sites, so expect a visible mismatch**
      on unmigrated screens — a kit card at 10 beside a hand-rolled one at 12. Said out
      loud rather than half-migrated.

### B2 · Bricolage Grotesque replaces Raleway

- [x] Vendored the four static instances into `assets/fonts/`: Regular 400, Medium 500,
      SemiBold 600, Bold 700 — the same four Raleway shipped, so no `TextStyle` changes
      weight. Verified each file's `usWeightClass` really is 400/500/600/700 rather than
      four copies of one instance.
- [x] Static instances, not the variable font. Flutter resolves `weight:` by picking a
      **file**, not by setting an axis, so one variable file would have rendered all four
      weights at its default instance.
- [x] **Checked the glyphs before committing**, which the plan did not think to ask for.
      `₹` is present — losing it would have emptied every statement PDF. `·`, `—` and
      `×` are there; `→` is there and was *not* in Raleway. `✓` is in neither, which is
      why `pdf_brand.dart` writes "Ph" rather than `☎`; that comment now names the
      behaviour instead of the old font.
- [x] ~~`AppType._family` and `ThemeData.fontFamily` are the only two places the name
      appears.~~ **Three.** `pdf_brand.dart` loads the TTFs out of the bundle by path for
      every generated statement and catalogue, and the plan missed it. A PDF rendered in
      a font the app no longer bundles is an asset-not-found at share time.
- [x] **Re-check sizes after the swap.** The roadmap already carries this risk for
      Raleway: it has a smaller x-height than Quicksand, so every size reads light.
      Bricolage Grotesque has a *larger* x-height than both. Expect the app to read
      heavier, not lighter. Do not chase it with size changes here — note the figures and
      let 10c, which touches all 198 of them, do it once.
- [x] Deleted the four Raleway files in the same commit. The bundle gets **smaller**:
      4 × 164 KB becomes 4 × 82 KB, so ~329 KB off the APK rather than the ~343 KB the
      Raleway swap added.

---

## C — Dashboard

### C1 · Bring the greeting back

Commit `ddd08d8` deleted it, for a good reason badly applied: the name came from
`const _greetingNames = ['Mohan', 'JMR']` picked by `Random()` at library load. That is
business identity hardcoded in a widget file, which AGENTS.md rule 6 forbids. The
greeting itself was never the problem.

- [x] Restored `Good morning / Good afternoon / Good evening` above the screen title, in
      the header's caption slot. The title answers what the screen *is*, and
      "Good morning" does not.
- [x] ~~Take the name from **Business Info** (`businessInfoProvider`), falling back to
      `BrandConfig.appName`.~~ **No name at all — the owner's call, 2026-09-05.**
      It was built with the business name first and taken back out. Two reasons it was
      never right: `BusinessInfo.name` names a *shopfront*, not a person, and the
      greeting the owner remembers said *Mohan*; and `BrandConfig.appName` is
      *Milano Orders*, so that fallback would have greeted the software. There is
      nowhere to keep a person's name without a schema change, and the chain is frozen
      at v6.

      Putting a person's name back is a decision about where to store it, not a
      formatting change. `shared_preferences` already holds the dashboard settings and
      would take it without touching the schema, if the owner ever wants it.
- [x] No literal names in `lib/`, per AGENTS.md rule 6.
- [x] Reads the hour through `package:clock`, per AGENTS.md rule 14. All three
      boundaries are asserted rather than sampled — a greeting that says "Good evening"
      at breakfast is the only way this can be wrong, and it is wrong on the app's first
      screen.
- [x] The title stays `Business Overview`. The greeting is the caption above it, not a
      replacement for it.

**One thing to know.**

The hour is read **when the header builds**. A phone left open across noon keeps the old
greeting until something else rebuilds the screen. The deleted version behaved the same
way, an hourly ticker for a caption is not worth a timer, and the screen rebuilds on
every refresh, range change and tab return.

---

## D — Orders list

### D1 · Two-line row

The owner's sketch:

```
| (avatar)  Shop Title   (status)                    ₹ amount |
| (avatar)  Location                                    N items |
```

One row, two lines, avatar spanning both, money in a straight right-hand column.

- [x] Left: the letter avatar, vertically centred across both lines.
- [x] Line 1: shop name, then the status mark (D2), then the amount, right-aligned.
      The mark needed a new slot on `ListRow`: `badge` sits at the *far* right, past
      the money, and a status mark belongs beside the name it describes.
      `titleBadge` is that slot, and it is `Flexible` so a long shop name ellipsizes
      rather than shoving the mark off the row.
- [x] Line 2: area on the left, item count on the right.
- [x] Amount and item count share one right-hand column so figures line up down the
      list. This is the decision commit `762be58` recorded for the ledger; it applies
      here for the same reason.
- [x] No order yet → the right column is empty. Never `₹0`, which reads as a real
      zero-rupee order.
- [x] ~~line 2 reads `Tap to add order`~~ — **the plan contradicted the sketch and the
      sketch won.** The sketch puts the area on line 2; the hint was the old card's
      third line, and a test caught the area disappearing. The hint now appears only
      when there is nothing else for that line — a shop with no area *and* no order.
      Everywhere else the amber mark and the empty money column already say the order
      is missing, and the whole row is the tap target.

**Collision note — now settled.** `shop_order_card.dart` is **deleted**. The screen is on
`ListRow`, so 10c's Home action item is done: strike it when 10c lands. The old card
spent a 16-padded card, an avatar, a title, an area row and a chip row on the same
information at roughly twice the height, and it was the last thing standing between this
screen and the row every other list already uses.

### D2 · Sticker marks, not pills

- [x] Confirmed → a filled green check, `AppTone.positive`. Pending → a filled amber
      warning, `AppTone.warning`. Both semantic, neither decorative.
- [x] Used the icon font, not PNG stickers. PNGs mean four assets per state per density,
      they do not take a theme colour, and the app already carries an icon set. If the
      owner wants illustrated stickers later, that is an asset swap behind the same
      widget.
- [x] `StatusBadge.mark`, a named constructor rather than a new widget or a flag.
      "A badge with no label" and "a badge whose label is empty" are different things
      and only one of them is legible to a screen reader, so the mode is not a
      parameter a call site can get wrong.
- [x] The label survives as the semantic name. A bare tick is meaningless to TalkBack.

      **`container: true` is load-bearing here.** `Icon` wraps its glyph in
      `ExcludeSemantics`, so a bare `Semantics(label:)` has no child node to annotate
      and drops the label on the floor. It was written that way first, and the test
      that asserts the label is what caught it — a "keeps the word for a screen reader"
      claim that quietly is not true looks exactly like one that is.

---

## E — Order entry

### E1 · Drop "Order Type", and what goes in its place

The info card is two columns: `Order Date` and `Order Type: Regular Order`. The second is
a hardcoded string. There is one order type. It has never told the owner anything.

- [x] Removed the Order Type column. The divider stays — there are still two
      columns.

**What to put there instead.** Ranked, from what the screen can already answer:

| | What it says | Why it earns the slot | Cost |
|---|---|---|---|
| **1** | **Last order** — `3 Sep · 47 items · ₹2,150` | This is the number the quantities get anchored to. Today the owner opens the shop and guesses, or backs out to Billing to look it up | One DAO read, additive |
| **2** | **Owes** — `₹4,320 · 12 days` | The other thing you want in front of you while a shopkeeper is standing there. `watchOutstandingByShop` already exists | Free — the query is shipped |
| 3 | **Standing order** — `Set · 24 items` or `Not set` | Says whether the ⋮ *Load standing order* action will do anything before you tap it | Free — already read on this screen |
| 4 | **Priced** — `26 of 28 priced` | Duplicates the orange banner below it | Free |

~~**Recommendation: 1 in the freed column, 2 as a badge beside the shop name.**~~

**The owner picked 3 — the standing order.** Better than the recommendation, and the
reason is one the ranking undersold: it is the only candidate that changes what the
*next tap* does. `Standing Order · 12 items` in the card and
`Load standing order (12 items)` in the menu are the same fact said twice, so the menu
answers "will this do anything" before it is opened, and the card answers it before the
menu is. Last order and Owes are things to know; this is a thing to act on.

It also costs nothing: `_init` already reads the standing orders to seed a new order and
was throwing the total away.

### E2 · Search and category filter under the Order Date card

28 products, one flat alphabetical list, at 5 a.m.

- [x] `AppSearchField` directly under the info card, matching product name.
- [x] ~~`FilterChipRow` of categories beneath it.~~ **The owner's call: one row, not
      two.** The filter is a button beside the search box that opens a sheet. Two
      full-width rows of controls above a list is the list getting shorter, on the
      screen that can least afford it — 28 products on a phone at 5 a.m. The button
      shows when a filter is on, because a filter you cannot see is a list that is
      wrong for no visible reason.
- [x] **Filtering never touches a quantity.** `_qtys` is keyed by product id and `_save`
      walks `_products`, not the visible list. Three tests hold it: a quantity set then
      filtered away is still saved, clearing the search brings the row back with its
      value, and Clear reaches rows it cannot see.
- [x] Clearing the search restores the full list.
- [x] A3 shipped first. Moot in the end — the chips became a sheet.
- [x] **One thing the plan did not foresee.** The category list is read through
      `categoriesProvider`, the one-shot, **not** a watched stream. A drift `QueryStream`
      schedules a zero-duration timer when it closes, and that lands after the widget
      tree is torn down: `order_entry_flush_test` failed on *"A Timer is still pending
      even after the widget tree was disposed"* and then hung the whole suite for three
      minutes. Categories are a master edited twice a year and never mid-order, so the
      live stream bought nothing and cost that.

### E3 · Steppers lose their background

`_StepperBtn` draws a 36×36 filled brown box behind each icon. Two of them per row, 28
rows, is 56 brown boxes on the busiest screen in the app.

- [x] Icon only. 36×36 target kept, `BoxDecoration` gone. The owner's note was to
      match the surrounding surface so it "looks the same"; no fill does that at every
      surface the row is ever drawn on, including the background art, where a white or
      cream pill would stand out more than the brown one did. Glyph up to 22 to hold
      its weight without the box.
- [x] Kept the press scale animation and the 400 ms long-press repeat from
      [doc 08](08-order-entry-swipe.md). Those are the feel; the box is not.
- [x] Disabled stays visibly disabled — `textTertiary`, not an invisible target.

### E4 · The whole row opens the quantity sheet

Today only the 40px number between the steppers is tappable.

- [x] The row is the `InkWell`. The steppers are children, so they win the hit test.
- [x] A tap on `+` does not also open the sheet.
- [x] The old `GestureDetector` around the number is gone with it — one handler, not
      two doing the same thing.
- [x] An unpriced product opens nothing, as before.

### E5 · Bigger wheels

`itemExtent: 40`, `width: 56`, box `height: 120`. Three digits in a 168px-wide cluster
is a thumb-width target for a swipe.

- [x] `itemExtent` 40 → **48**. Wheel width 56 → **72**. Box height 120 → **200**.
- [x] The selection band is drawn **once, behind all three wheels**, not three times.
      `CupertinoPicker`'s own overlay is per-picker and would have drawn three separate
      bands with gaps between them; each wheel passes `SizedBox.shrink()` and the sheet
      paints one band under the row, so it reads as one control.
- [x] Digit size 22 → 28, via `AppType.displayL` rather than another literal.
- [x] Kept the per-notch haptic. It is why the wheel feels like anything at all.

### E6 · `0` is a placeholder, not a value

`_ctrl = TextEditingController(text: widget.initialQty.toString())` seeds `"0"`, so the
owner types `5` into a field containing `0` and gets `50` or `05` depending on where the
caret sits.

- [x] The controller is **empty** at 0.
- [x] `hintText: '0'` for the ghost.
- [x] Empty on confirm means 0, not "leave unchanged".
- [x] A non-zero quantity seeds its real value, **selected**, so typing replaces it.
      The row's own quantity column also greys a zero now, so the two agree about what
      "nothing ordered" looks like.

### E7 · Three-dot menu in the header

`Load Standing Order` is a text button in `AppBar.actions`, competing with the shop name
for width.

- [x] One `PopupMenuButton` with two items:
      - **Load standing order** — the existing action, existing confirm dialog.
      - **Clear all quantities** — new. Sets every quantity to 0.
- [x] Clear goes through `confirmDestructive`, per AGENTS.md rule 16.
- [x] Clear writes through the same debounced save path — it is an edit, not a
      special case — and reaches filtered-out rows.
- [x] Clearing a confirmed order un-confirms it, exactly as editing a quantity does.
- [x] The item names its own size — `Load standing order (12 items)` — or is disabled
      reading `No standing order set`.

---

## F — Kitchen

### F1 · Drop the unit line under By Item

`ListTile(subtitle: unit != null ? Text('per $unit') : null)`. "per pc" under every row,
on the screen that exists to be read across a kitchen.

- [x] Remove the subtitle. The quantity column already carries the meaning.
- [x] Match By Shop's row shape, which has no second line. The identical
      `bakery_dining` avatar went with it — under a category header carrying the
      category's own emoji, a leading icon that is the same on every row says
      even less than it did before.

### F2 · By Item groups by category

By Shop groups by shop. By Item is a flat list, and the bake order is by category.

- [x] Group by `categoryId`, using the same category sort order as the share text
      already does in `_shareItems`. That grouping logic exists; reuse it rather than
      writing a second one that can disagree.
- [x] Uncategorised products fall into an **Others** group, last.
- [x] Category header carries the emoji and the group's total quantity. Written
      `50 pcs`, the way By Shop already writes a group total — and the row below
      it writes a bare `50`, so the two numbers never read as one.
- [x] The share text and the screen must produce the same grouping. One function, two
      renderers.

**How it landed.** `_shareItems` did the grouping inline, so reusing it meant
lifting it out first: `lib/services/kitchen_list.dart` now holds
`groupKitchenLines()` and `kitchenListText()`, and `KitchenScreen.build` calls
the grouper **once** and hands the same `List<KitchenGroup>` to the By Item tab
and to the share sheet. There is no second code path left to drift.

Two rules the old inline version already had, kept and now tested: a product
whose category has since been **deleted** falls into Others rather than off the
list, and a quantity that nets to zero across shops is not a bake instruction.
By Item became a list of cards, one per category, matching By Shop — it was a
single fixed card with an internal scroll and a `Item / Quantity` column header
that the new group headers make redundant.

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

- [x] Rows 1 and 2 are the shop and its money. Row 3 is a separated action strip: the
      two status pills on the left, share on the right.
- [x] A hairline divider between row 2 and row 3. "Clear separation" is the point.
      Full-bleed, so the card reads as two zones rather than one with a line in it.
- [x] Money right-aligned in one column, as D1.
- [x] **Keep both existing gestures unchanged**: long-press records a payment, tap
      expands the line items, `_expandedOrderId` behaviour identical.
- [x] The share icon moves out of the crowded trailing cluster into row 3, which is what
      the `FittedBox` scale-down hack at `orders_screen.dart:396` was working around.
      Delete the hack with it. A test asserts there is no `FittedBox` left on the screen.

**The second amount.** The sketch's row 2 carries an amount under the total and does not
say which. It is now **what is still owed** — `₹350 due`, in the negative tone — falling
back to the order's size (`7 items`, as on the Home row) when the bill is settled. A bill
that is paid has no outstanding figure worth showing, and printing `₹0 due` down the
whole list would bury the three rows that are not paid. Tell me if you meant something
else by it.

**The caret stayed.** Row 3 in the sketch carries only share. But the caret is the only
thing on the card that says tapping it does anything, and the expand gesture is how the
line items are read, so it sits beside share rather than disappearing.

### G2 · "Share bills", with a picker

- [x] Rename `Share All Bills` → **Share bills**.
- [x] On tap, open a shop multi-select sheet. All selected by default — the common case
      is still all of them.
- [x] Share the selected shops only, and total only those. A partial share whose
      GRAND TOTAL is the full day's figure is a wrong number sent to a customer.
- [x] Reuse `catalog_share_picker_screen.dart`'s selection shape if it fits. Do not write
      a second multi-select.

**How the reuse went.** The catalogue picker's selection shape could not be *called* —
it was a full screen, hard-wired to products, with its select-all in the app bar. So it
was lifted instead: `MultiSelectList` in the kit owns the ticking, the select-all and the
`3 of 8` header; `showMultiSelectSheet` wraps it in a sheet with a confirm button. The
bills picker is the sheet. The catalogue screen keeps its own chrome and its PDF/text
step but its body is now the same widget, and its app-bar `Select All` is gone — the
control belongs above the list it selects. One implementation, two callers.

**The number that mattered.** `billsSummaryText` moved into `lib/services/bill_share.dart`
so it could be tested directly, alongside `billDetailText`. The test that earns its keep
totals two of three shops and asserts the GRAND TOTAL is those two.

---

## H — Ledger, was Finances

### H1 · Rename

- [x] `Finances` → **Ledger**, in `destinations.dart` and nowhere else. Rule 12.
- [x] Keep the route `/finances`. A path rename buys nothing and costs a redirect rule.
      `finances` became a *keyword* on the destination, so the old name still finds the
      screen from the settings search. A test holds that.
- [x] **Watch the collision.** Confirmed by the owner: the per-shop screen is a
      **Statement**. Its header now reads `<Shop name>` over `Statement · <area>`, the
      fallback title is `Statement`, and the Shops master's row button says Statement.
      Its PDF export already said "Export Statement", so the word was half there.
- [x] Do not rename the files. `finances_screen.dart` staying put is a smaller diff than
      a rename nobody can grep for later.

### H2 · Period filter, defaulting to All time

The screen is fixed at 30 days, deliberately, per its own doc comment. The owner has
overruled that. Record it rather than silently deleting the comment.

- [x] ~~Reuse `DateRangePill`~~ — **it could not be reused, and the owner chose a
      dropdown.** The pill is bound to `dashboardRangeProvider`: sharing it would have
      meant changing the period on Ledger also changed it on the Dashboard, and adding
      `All time` to the shared preset list would have put it on the Dashboard's pill too,
      which this section forbids two lines down. A `PopupMenuButton` in the section
      header instead, on its own state.
- [x] Add an **All time** option; make it the default here. The dashboard's default does
      not change.
- [x] The filter drives the summary band. **Not the outstanding figure** — see below.
- [x] **Outstanding is a balance, not a period figure.** "What is owed to me as of today"
      does not change because you asked about last week. Filter the *billed / collected /
      net* band; leave the hero total as the live balance and label it so. The hero
      caption is now `Outstanding right now`, and a test changes the period and asserts
      the figure does not move.

`LedgerPeriod` lives in `lib/utils/ledger_period.dart` with seven tests on its date
arithmetic alone — year boundaries, leap February, and the fact that `Last 30 days` is
now thirty days rather than the thirty-one the old fixed window counted.

### H3 · Fold the caption into the stat card

`SectionHeader(title: 'Last 30 days', caption: 'Billed against collected')` draws the
caption in `textTertiary` over the background art. It is not readable.

- [x] Move `billed · collected · net` into the stat card itself, labelled in place.
      `StatBand` already labelled each figure, so this was the caption's deletion.
- [x] Delete the separate caption row. The labels under each figure say it better than a
      heading above three of them. The header now reads `Billed and collected` with the
      period control on its right.
- [x] Check the same pattern anywhere else a tertiary caption sits directly on the
      background. **This was the only one.** Every other `caption:` in the app belongs to
      `AppScaffold` or `HeroStatCard`, which draw it on a header or inside a card.

### H4 · Sort "Who owes"

- [x] A sort control on the section header: **by amount** (default, as now) and
      **by name**.
- [x] Sort in the screen, not in a new query. 18 rows.
- [x] The choice does not need to persist across launches. It is a field on the screen's
      state, which is also what let the period control be one.

---

## I — Masters

### I1 · Shops row

- [x] `Ledger` moves out of the footer to the **right of the row, vertically centred**.
      As an icon, not the word: the word plus the ⋮ eats a third of a narrow
      row, and the name has to fit next to it.
- [x] `Deactivate` / `Activate` moves into a ⋮ menu on the same right edge.
- [x] The footer row disappears with them, so the row loses a line. `Inactive`
      moved from the far right to beside the name — a state badge parked among
      buttons reads as one of them.
- [x] Deactivate keeps its confirm. It is destructive to a shop's history.
      **It did not have one.** The footer button wrote straight to the dao. It
      has one now, naming the shop and saying what deactivating takes it off.

### I2 · Products row

- [x] `Deactivate` / `Activate` into a ⋮ menu, as I1. The footer goes.
- [x] Subtitle carries **price · unit · category**: `₹22 · pc · 🥐 Puffs`.
- [x] The price is the product's own default price, not a per-shop price. Say `Price not
      set` when it is null rather than leaving a gap. Per-shop prices are the price
      matrix's job and must not be implied here.

No confirm on the product toggle, because I2 does not ask for one and a
deactivated product is not a shop's history. Say if you want it symmetrical.

### I3 · Search on Standing Orders and Price Matrix

Both screens list every product for a chosen shop, unsearchable.

- [x] `AppSearchField` above the product list on each, matching name.
- [x] **Filtering must not drop an edit.** Both hold a `Map<int, TextEditingController>`
      built per shop; filtering must hide rows, never rebuild or dispose the controllers,
      or a typed price vanishes when you clear the search.
- [x] Save still writes every controller, not just the visible ones. The button
      says so — `Save all 12 products` — counting what exists, not what is on
      screen, so the label cannot quietly drift from the behaviour.

**Held by tests, not by reading.** Four of the six in `masters_editors_test.dart`
do the dangerous thing directly: type a value, search it off the screen, then
either clear the search and read the controller back, or save and read the
database back. The list body moved into a private `_ProductQuantities` /
`_ProductPrices` widget on each screen, taking `products` (what exists) and
`visible` (what is drawn) as separate parameters — so the two can be told apart
at a glance instead of by remembering which list is which.

Both files were run through `dart format`, which is why their diffs are larger
than the change. The new code was spliced into deeply nested branches and would
otherwise have been indented to nothing.

**Collision note.** 10c rebuilds the price matrix on `ListView.builder` with a sticky
column. The search box is additive and independent of that. Keep them separate.

---

## J — Navigation and motion

### J1 · The bottom bar hides on scroll down

- [x] Hide on scroll down, show on scroll up, show at rest.
- [x] **This means moving the bar out of `Scaffold.bottomNavigationBar`.** That slot
      insets the body, so animating the bar's height reflows every screen on every
      frame. It goes into `AppShell`'s existing `Stack` as a bottom-positioned overlay
      with a slide transition — which is also where `app_shell.dart`'s own comment says
      the background had to go, for the same reason.
- [x] Every shell screen then needs bottom padding of its own. Most already carry
      `bottom: 96` or `100`; make it one constant instead of four guesses.
      `AppShell.bottomInset(context)` — the bar's own height, its margins, a gap, and the
      gesture inset it sits above. It is a function rather than a constant because the
      last of those is only known from the `MediaQuery`, and 96 was wrong on a phone with
      a home indicator.
- [x] Respect `MediaQuery.disableAnimations` — no slide, bar always visible. A control
      that disappears is exactly the movement the setting turns off, and hiding it
      *without* the slide would be worse rather than better.
- [x] **This is the riskiest item in this doc.** It changes the layout contract of all
      five branch screens. Land it on its own commit, after everything else, so it can be
      reverted without taking the rest with it.

**`idle` does not show the bar.** Scrolling down and lifting your finger would bring it
straight back, which is a flicker rather than a feature. At rest the bar stays where the
last gesture left it — unless that rest is at the top of the list, which is the "show at
rest" that matters. A list too short to scroll never hides it at all.

**Horizontal strips are scroll views too.** The date-range pills and the category chips
would each have hidden the bar on a sideways swipe. The listener takes vertical
notifications only, and a test swipes a chip row to hold that.

**Billing's grand-total card was the awkward one.** It is not in the scrolling list — it
sits under it, in the same `Column` — so the inset went on the card's padding rather than
the list's, and the day's figure stays above the bar rather than behind it.

### J2 · Relative date labels

`DateSelector` shows `05 Sep 2026, Fri` and nothing else, on Orders, Kitchen and Billing.

- [x] One `relativeDayLabel(DateTime, {required DateTime today})` in `lib/utils/`, pure,
      unit-tested, used by all three screens. Never three copies — they share one
      `DateSelector`, so it is one call site.
- [x] The ladder, with one change: **the last row returns null, not `12 Sep`.** The
      owner chose date-first (below), so the date is already the line above. `12 Sep`
      under `12 Sep 2026, Sat` is the same fact twice.
      | Distance | Label |
      |---|---|
      | 0 | `Today` |
      | +1 / −1 | `Tomorrow` / `Yesterday` |
      | same calendar week | `This Mon` … `This Sun` |
      | next / previous calendar week | `Next Tue` / `Last Tue` |
      | anything else | `12 Sep`, with the year when it is not this year |
- [x] **The owner chose the other way round: date big, word small.** `05 Sep 2026, Fri`
      stays the headline it already was, with `Today` / `Next Tue` in small type under
      it. Less of a change from what is there, and the date a bill is read out from
      never moves.
- [x] Weeks are Monday-start, matching the heatmap's day labels.
- [x] Read today through `todayProvider`, so the label re-derives at midnight along with
      everything else.

Day arithmetic goes through a UTC day number, not `DateTime.difference`. Between two
local midnights across a daylight-saving boundary that difference is 23 hours, and
`inDays` truncates it to zero — so tomorrow would read as `Today`. India has no DST, so
this would never have been caught here.

> **Confirmed by the owner.** "fortnite" was *fortnight*, and it is covered by the
> `Next` / `Last` week rows above — a fortnight is a span, not a day, so it cannot be a
> label on a single-day selector.

### J3 · Scroll to top on screen change

`StatefulShellRoute.indexedStack` preserves each branch's scroll position by design,
which is right for a back press and wrong for a tab switch.

- [x] ~~When a branch becomes visible~~ — **when it stops being visible.** Same result,
      one fewer frame wrong: resetting on the way in paints the old offset once before
      the jump lands. On the way out the branch is already offstage.
- [x] Jump, do not animate. An animated scroll on a screen you are already looking at
      reads as a glitch.
- [x] Tapping the current tab already resets it via `goBranch(initialLocation: true)`.
      Do not add a second mechanism that fights it. Nothing was added to the bar.
- [x] A back press returning to a branch keeps its position. Only a switch resets. A push
      inside a branch does not change its `TickerMode`, which is what this hangs off.

**The signal.** `StatefulShellRoute` wraps each branch in a `TickerMode`, and that
notifies its dependents. `StatefulNavigationShell.of` looks like the obvious hook but is
`findAncestorStateOfType` — no notification, so nothing can be woken by it.
`BranchScrollScope` gives each branch its own `PrimaryScrollController`, which a bare
`ListView` attaches to; a screen that passes its own controller opts out silently, so a
test asserts the attachment.

### J4 · Catalogue returns to Settings

`settings_screen.dart` carries a long comment explaining why the masters are *not*
listed there, and 10b's own build notes say the opposite ("the owner chose both"). The
code won. The owner has now chosen both again.

- [x] A **Catalogue** card in Settings: Shops, Products, Categories, Price Matrix.
- [x] Build it from `destinationsIn(DestGroup.catalogue)` plus the Price Matrix, not from
      a hand-written list. Rule 12: a destination is added in `destinations.dart` and
      nowhere else.
- [x] Each row gets a live summary, like every other Settings row —
      `18 active · 2 inactive`, `212 of 504 prices set`. ~~The aggregates exist already
      on `catalogueCoverageProvider`~~ — only the price ones do. The active/inactive
      splits come from the three `all*Provider` streams the screen already watched. No
      new query.
- [x] Delete the comment that says they are not there, and fix 10b's build note. A doc
      that describes the opposite of the code is worse than no doc. 10b's deviation note
      #2 now records that the note and the code disagreed for a release.

**The search does not list them twice.** Settings search already returns every
destination under *Screens*; repeating the catalogue rows under *Settings* would return
Shops twice for one query. The card is on the full screen only.

---

## K — Second device pass

The owner ran the branch again after A–J landed. Twelve points, all small, all
from the phone.

### K1 · Dashboard header

- [x] The date on the left, a **period dropdown** on the right, replacing the
      scrolling row of seven pills. That row spent a whole band of the screen on
      a control touched once a week.
- [x] The pill widget is deleted. `HeaderMenu` moved out of `finances_screen`
      into the kit, so the Dashboard and the Ledger use one control on two
      pieces of state — which is what H2 could not do while the pill existed.
- [x] `Custom…` still opens the range picker, now reading `todayProvider`
      rather than `DateTime.now()`.

### K2 · The Pulse is a daily card

- [x] Shown only when the period is **Today**. It answers "how is today going";
      against a quarter that is a different question, and one the cards below
      already answer. The Dashboard-sections setting still switches it off
      entirely.

### K3 · The Dashboard is named after the business

- [x] The title is the **Business Name** from Settings, falling back to
      `Business Overview` when it is blank — confirmed with the owner, who meant
      their own bakery rather than one of the shops they supply. Read from
      `businessInfoProvider`; nothing is hardcoded, per rule 12.

### K4 · Two height overflows

`Category Revenue Mix` and `Product Leaderboard` both pinned a height around an
icon over a line of text. That fits at the default font scale and overflows one
notch up, which is what the phone was reporting.

- [x] Both empty states are padded rather than pinned, so they size to content.
- [x] The donut's centre figure is clamped to one line, so it cannot grow past
      the box the chart is drawn in.
- [x] The leaderboard's rank cell was 32px for a two-digit rank beside an emoji.
      Now 40, with the emoji flexible and the header spacer moved to match —
      row ten is the row that card exists to show.

### K5 · A solid nav bar

- [x] Full width, running to the bottom edge, with the top two corners rounded
      (`AppRadius.barTop`). The pill left a gap on all four sides and the page
      scrolling behind that gap read as a mistake rather than as depth.
- [x] The gesture inset moved *inside* the bar, so the fill reaches the bottom
      of the screen while the slots stay above the home indicator.
- [x] **Shown again at the bottom of a list.** There is nothing left to scroll
      for down there, so making the owner swipe up to get the bar back would be
      asking for nothing. Held by a test that scrolls to `maxScrollExtent`.

### K6 · Background art on the main five only

- [x] Back in `AppShell`, behind the five branches. A4 moved it up to
      `MaterialApp.builder` so pushed screens got it too; on the phone that was
      too much — order entry, a statement and the masters are working screens,
      and a photograph behind a column of numbers is noise.
- [x] It could not have come back before J1. `bottomNavigationBar` insets the
      body, so a background inside the Scaffold was laid out ~80px shorter on
      shell routes and `BoxFit.cover` rescaled the art when you popped back from
      a sub-route. The bar is an overlay now, so the crop is stable.
- [x] Pushed screens sit on flat `AppColors.bg`, painted once in the builder.

### K7 · The rest

- [x] **Order entry** — the quantity wheel was left-aligned. The sheet's column
      is `crossAxisAlignment.start` so the name and the Wheel/Input toggle share
      an edge, and the wheel block was the one child narrow enough to sit off to
      one side of it. Centred.
- [x] **Kitchen** — onto `AppScaffold`, like every other shell screen. Its
      hand-rolled header is why its menu button sat on a different left edge.
      This is A5 finally reaching the fifth screen.
- [x] **Billing** — the line total in the expanded item list dropped from `w600`
      to normal. Bolding one column of a four-column table makes the eye read
      down it instead of across the row.
- [x] **One share icon.** `Icons.ios_share_rounded` everywhere. Kitchen had two
      of its own — `share_rounded` in the header and `share` on the shop rows.
- [x] **Price Matrix** — the shop dropdown overflowed by 3px. A name with an
      area is longer than the field, and left to wrap it burst the menu row's
      fixed height. `isExpanded` plus a one-line clamp, applied to Standing
      Orders' identical dropdown at the same time rather than leaving it latent.

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

## Progress

| | Commit | Note |
|---|---|---|
| A1 · back button | `f99231d` | Both buttons, including the loading branch |
| A2 · heatmap | `894b908` | Fixed in Dart, not with `'unixepoch'` — see A2 |
| A3 · filter pills | `f848475` | The cause was the row's own padding, not the emoji |
| A4 · background | `9516e2b` | Painted app-wide; new artwork still to come |
| A5 · header gutter | `480ba82` | Took Dashboard, Orders and Billing onto `AppScaffold` |
| A1 test fix | `5ff1187` | `io()` gapped before the route was built |
| B1 + B2 · radius and face | `4d2a46b` | One commit — they land together on every screen |
| C1 · greeting | `cd80e2d` + `409f0aa` | Greeting back, no name — the owner's call |
| D1 + D2 · Orders row and marks | `a5c2c43` | `ShopOrderCard` deleted; 10c's Home item is done |
| E1–E7 · Order entry | `a63bc85` | Standing order, one filter row, and a suite-hanging timer |
| F1 + F2 · Kitchen | `937e2f8` | Grouping lifted into `kitchen_list.dart`; screen and share share it |
| G1 + G2 · Billing | `1755496` | Three rows, a real picker, and `MultiSelectList` in the kit |
| I1–I3 · Masters | `6f62c52` | Right-edge actions, price in the subtitle, search that keeps edits |
| H1–H4 · Ledger | `2203703` | Renamed, its own period, sortable — and a `Statement` next to it |
| J2–J4 · Nav, minus the bar | `0b58194` | Relative dates, scroll reset, Catalogue back in Settings |
| J1 · The hiding bar | `fee9802` | Out of the Scaffold slot, into an overlay. Alone, as planned |
| K1–K7 · Second pass | see below | Twelve points from the second phone run |

### Verified — 2026-09-05, Flutter 3.44.2 / Dart 3.12.2

The same version CI pins in `.github/workflows/release.yml`, so these numbers
are the ones CI will see.

| Gate | Result |
|---|---|
| `flutter test` | **336 passing, 0 failing** — was 203 when 10b was built |
| `flutter analyze` | **0 errors, 0 warnings.** 48 infos, all deprecation |
| `tool/check_tokens.sh` | **289**, from 354. Kit clean |

`flutter analyze` is **not** clean, and none of it is new:

- **53 infos**, every one a `@Deprecated` `kBrandGold` / `kBrandBrown` /
  `kSurface` alias. This is 10c's progress bar by design — see
  [10c](10c-screen-restyle.md)'s *Closing the ratchet*. It went **down** here,
  because A5 took three screens off the aliases, D deleted a widget that used
  three more, and F, G and H's rewrites use none.
- **No warnings.** There were six when this branch started, all pre-dating it:
  three unused imports and three unused test helpers. Five of them sat on lines
  that F, G, H and J rewrote, so they went with the rewrites. The last, a dead
  `owes` helper in `shell_test`, was deleted here rather than left for whoever
  bumps the version — one dead local function is not worth carrying to block a
  gate.

`flutter analyze` is therefore **clean** by the roadmap's readiness definition:
zero errors and zero warnings. The infos are the deprecation ratchet 10c
closes.

## Order of work

1. **A1, A2, A3** — three defects, three small commits, independently revertable.
2. **B1, B2** — the two global swaps. Everything after this sees the new radius and font.
3. **A4, A5** — background and header, which move shared widgets.
4. **C, E, F, G, H, I** — screen by screen, one commit each.
5. **J2, J3, J4** — additive.
6. **J1** — last, alone. It changes the layout contract of all five branch screens.

D1 rides with E, since both touch the Orders flow and the owner reads them together.
