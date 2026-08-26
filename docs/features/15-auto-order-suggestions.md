# 15 — Auto order suggestions

| | |
|---|---|
| **Target version** | `2.1.0+21` |
| **Type** | Feature |
| **Schema** | No change |
| **Requires** | [14 — Supabase, auth & roles](14-supabase-auth.md) |
| **Builds on** | [10a — Design system & UI foundation](10a-design-system.md) — this screen is what its component kit was designed against |
| **Followed by** | [16 — Weekly AI report](16-weekly-ai-report.md) |
| **Status** | **Outline** — expand action items before starting |

## Why

Every morning the owner opens each of ~18 shops in turn and types the day's
quantities in from memory. Eighteen shops at ten to fifteen lines each is roughly
**200 numbers typed before 6 a.m.**, and most of them are the same numbers as last
Tuesday's. It takes twenty to twenty-five minutes at the worst hour of the day, and
it is the one part of the morning that a database with eight weeks of history should
be doing for him.

Standing orders were meant to solve this and do not. `standing_orders.defaultQty` is
a number the owner typed once, months ago. It does not know that Aavin 2 has been
taking twenty egg puffs every Monday since June, or that Cafe Milano stopped moving
jam buns three weeks ago. The order history knows both.

Getting it wrong costs real money in both directions, and the two directions are not
symmetric:

- **Over-order.** Puffs, buns and rolls are same-day goods. Twenty extra puffs at a
  shop is ₹240 of production that comes back as waste or as a complaint.
- **Under-order.** The shop sells out by 10 a.m. and the owner loses the rest of the
  day's sales at that counter — and the shop starts asking the competitor.

So this screen proposes each shop's likely order for a chosen date and lets the owner
**accept, edit or skip, per shop**. It does not decide anything. It removes the
typing, not the judgement.

**Explicitly out of scope: this feature does not order anything.** It sends no
message to any shop, writes nothing to WhatsApp, and touches no row in the database
until the owner presses **Create All Orders**. It is a prefill, and a prefill that is
wrong costs one tap to fix.

**It also uses no model.** There is no LLM anywhere in this doc — the suggestion is
arithmetic the owner can check on paper, and that is the point.
[Doc 16](16-weekly-ai-report.md) is where a model enters this project, and it enters
it to write prose, not to pick quantities.

## The algorithm

It has to be explainable to a shop owner in one sentence, because the owner is going
to be asked "why are you sending me twenty today?" and "the app said so" is not an
answer. The sentence is:

> **We take what this shop ordered on the last four Mondays, use the middle value,
> nudge it by how the last two weeks have moved, and never go above double or below
> half your standing order.**

Everything below is that sentence, stated precisely.

### The rule

For a shop `S`, product `P` and target date `D` falling on weekday `W`:

1. **Base — same-weekday recent median.** Take `S`'s ordered quantity of `P` on the
   last **4 occurrences of `W`** found within the last **8 weeks**. `base = median`,
   rounded to a whole unit. A day on which `S` had no order row at all is not an
   observation and is skipped; a day on which `S` ordered zero of `P` **is** an
   observation and counts as 0.
2. **Trend.** `trend = (S`'s total qty of `P` over the last 14 days) `/` (the same
   over the 14 days before that), **clamped to `[0.85, 1.15]`**. Applies only when
   both windows contain at least 2 orders for `S`; otherwise `trend = 1.0`.
3. **Combine.** `raw = base × trend`.
4. **Clamp against the standing order.** Where `standing_orders.defaultQty` exists
   for `(S, P)`, clamp `raw` to `[0.5 × defaultQty, 2 × defaultQty]`. The standing
   order is the owner's own written statement of what normal is; history is allowed
   to move within that band on its own and not outside it.
5. **Round.** To a whole unit below 20, and to the **nearest 5** at 20 and above.

Median rather than mean, deliberately: one festival Monday at 60 puffs drags a mean
of four observations up by twelve units and stays in the number for a month. The
median ignores it. That is exactly the behaviour wanted, because a festival is
precisely the thing this algorithm is not allowed to guess about.

Rounding to 5 above 20 is arguable. The alternative — round to 1 — was rejected as
false precision: nobody bakes 23 puffs, the trays do not work that way, and a
suggestion of 23 invites the owner to distrust the whole column. Below 20 the units
are large enough individually that rounding to 5 would be a real error, so it
switches.

### The computed shape

**No new tables.** A suggestion is a computed value, not a record. Storing them would
create a second source of truth about what an order should be, would need a backup
round-trip and a migration, and would be worthless five minutes after it was
computed.

```
SuggestedLine       (computed, never persisted)
  productId
  usualQty          -- the base from step 1
  suggestedQty      -- after trend, clamp and rounding
  delta             -- suggestedQty − usualQty
  reasonCode        -- one value of a fixed enum, never free text

SuggestedOrder      (computed, never persisted)
  shopId
  date
  lines             -- only products with usualQty > 0 or a standing order
  usualValue        -- ₹, at this shop's prices
  suggestedValue    -- ₹
  confidence        -- confident | needsReview | noOrder | notSuggestable
  reason            -- the dominant line's reasonCode, promoted to the card
```

Two things that are easy to get backwards:

- **`usualQty` is the base, not the standing order.** The "Usual Qty" column on the
  screen shows what the shop has actually been taking, which is the number the owner
  is being asked to compare against. Showing `defaultQty` there would compare the
  suggestion to a figure nobody has looked at since March.
- **Price resolution follows order entry exactly** — `shop_prices` for that shop,
  falling back to `products.price`. A different resolution order here would make
  Total Value disagree with the billing screen for the same quantities, and the first
  time that happens the feature loses the owner's trust permanently.

### The reason string

Every line carries a `reasonCode` from a **fixed enum**, rendered through a fixed
template with the figures interpolated. It is never generated, never free text, and
never longer than one line:

| `reasonCode` | Renders as |
|---|---|
| `weekdayHigher` | "Higher sales on Mondays" |
| `weekdayLower` | "Lower sales on Mondays" |
| `trendUp` | "Up over the last two weeks" |
| `trendDown` | "Lower sales last week" |
| `clampedHigh` | "Capped at twice the standing order" |
| `clampedLow` | "Held at half the standing order" |
| `newShop` | "New shop — using the standing order" |
| `thinHistory` | "Only 2 weeks of history for this shop" |
| `steady` | "Same as usual" |

The card's banner shows the reason of the line with the largest absolute ₹ delta. If
the owner cannot read that sentence and immediately say "yes, that's right" or "no,
that's wrong", the algorithm has failed regardless of its arithmetic.

### What it will not handle

Stated plainly, because a suggestion engine that is quiet about its blind spots is
worse than none:

- **Festivals.** Diwali, Pongal, Ramzan, a temple festival on one shop's street. The
  app has no calendar and this doc does not add one. Every festival week will be
  under-suggested and the owner must edit.
- **Weather.** A wet evening in Chennai kills counter sales; the algorithm finds out
  a week later, if at all.
- **One-off events.** A wedding order, a shop's own promotion, a shop that phoned
  this morning to say "double the rolls".
- **Price changes.** ₹ figures move with prices; the quantities do not react to them.
- **A new competitor next door**, a shop about to close, a road dug up outside.

The override path is the whole screen: **Use Suggested**, **Edit Order**, or **Skip**,
per shop, before anything is written. The owner is never obliged to look at a shop he
already knows the answer for — that is what the collapsed cards on **All Shops** are.

### Cold start

| Situation | Behaviour |
|---|---|
| New shop, has a standing order | Suggest exactly the standing order. `reasonCode = newShop`. **Always** Needs Review. |
| New shop, no standing order | No suggestion. Card sits under **No Order** reading "No history yet — enter this order by hand". |
| Shop with 1–2 same-weekday observations | Suggest from the median of all its recent observations, ignore trend, force Needs Review with `thinHistory`. |
| New product, shop has never taken it | **Never suggested.** A suggestion may not introduce a product a shop has never ordered, standing order or not — that is a sales decision, not a forecast. |
| Product the shop has stopped taking (0 observations in 8 weeks) | Dropped to 0, shown as a changed line with a negative delta, and the shop is forced to Needs Review. A silent disappearance is the worst possible failure here. |
| Shop already has an order for `D` | Excluded entirely. Never counted, never overwritten. |

### Confidence and the Needs Review threshold

A shop lands in **Needs Review** if **any** of the following holds. Otherwise it is
Confident and sits collapsed under **All Shops**:

- the order's suggested value differs from its usual value by more than **±10% or
  ₹200**, whichever is larger;
- any single line's `suggestedQty` differs from its `usualQty` by more than **50%**;
- fewer than **3** same-weekday observations exist for the shop;
- a clamp was applied at step 4;
- a line dropped to zero.

The thresholds are the tuning surface of this feature and will be wrong on the first
attempt. They are constants in one place in
`lib/services/order_suggestion_service.dart`, not scattered across the UI, precisely
so they can be moved after a fortnight of real mornings.

**Needs Review is a triage list, not a warning.** With 18 shops, two or three cards
open for inspection is the design target; eighteen open cards is the same screen the
owner already has and the feature has failed.

## Outline of work

### Algorithm

- [ ] `lib/services/order_suggestion_service.dart` — new, **pure Dart, no database
      access**. Takes history, standing orders and prices as plain lists and returns
      `List<SuggestedOrder>`. Pure so the whole algorithm is testable without a
      database, an app, or a device — which is the only way the fixture tests below
      are affordable.
- [ ] `lib/models/suggestion_models.dart` — new. `SuggestedLine`, `SuggestedOrder`,
      `SuggestionReason` enum, `SuggestionConfidence` enum.
- [ ] Thresholds (`0.85`/`1.15`, `0.5`/`2.0`, `±10%`/`₹200`, `50%`, `3`
      observations, `4`-of-`8`-weeks) as named constants in one block at the top of
      the service. No magic numbers below that block.
- [ ] `lib/database/daos/suggestion_dao.dart` — new. **One** query returning 8 weeks
      of `order_lines` joined to `daily_orders` for all active shops, plus one for
      standing orders and one for prices. Three round trips total, never per-shop.
      *(After [doc 14](14-supabase-auth.md) this is a Supabase query module rather
      than a Drift DAO; it belongs wherever that port put the others and keeps the
      same DAO-shaped interface, per doc 14's rule that provider signatures do not
      change.)*

### Providers

- [ ] `lib/providers/suggestion_provider.dart` — new.
      `suggestionsForDateProvider` (`.family` on `DateTime`, mirroring
      `ordersForDateProvider` in `lib/providers/order_provider.dart`),
      `suggestionFilterProvider`, and `suggestionOverridesProvider` — a
      `StateNotifier` holding per-shop accepted / edited / skipped state **in memory
      only**, reset when the date changes.
- [ ] Every one of them **`autoDispose`**, per [doc 10a](10a-design-system.md)'s rule
      that anything keyed on an argument disposes. A date-keyed provider holding eight
      weeks of history is the exact shape of leak that doc 10a's audit found.
- [ ] Reuse `selectedDateProvider` from `lib/providers/date_provider.dart`. The owner
      picks the date once; a second independent date state on this screen is a bug
      waiting to be reported as "it created orders for the wrong day".
- [ ] Doc 04's rules apply: one aggregate, no N+1, no duplicate query across the
      summary card and the shop cards.

### UI

The screen design is finished, and so is the toolkit for it:
[doc 10a](10a-design-system.md)'s component kit in `lib/widgets/ui/` was specified
against **this mock**. `StatBand`, `FilterChipRow`, `SectionHeader`, `StatusBadge`,
`DeltaPill`, `MiniTable`, `NoteBanner`, `AppCard`, `AppButton` and `AppScaffold` all
exist before this doc starts. **Build no new UI primitives here.** If this screen
needs a widget the kit does not have, it goes into the kit with a doc comment, not
into this screen as a private class.

- [ ] `lib/screens/suggestions/auto_suggestions_screen.dart` — new, on `AppScaffold`.
- [ ] `lib/app.dart` — `AppRoutes.suggestions = '/suggestions'`. Registered as a
      drawer destination in `lib/widgets/shell/drawer_destinations.dart` and reachable
      from the quick-action sheet, both per [doc 10b](10b-navigation.md).
- [ ] Header via `AppScaffold`: title **Auto Order Suggestions**, a `StatusBadge`
      reading **Beta** beside it, the subtitle beneath, and an **(i)** action.
- [ ] **Subtitle copy: "Suggested from this shop's order history."** The design reads
      "AI-powered suggestions based on history"; that wording loses, because there is
      no model here and the entire value of the feature is that the owner can check
      the number. Telling him it came from an AI is an invitation to stop checking,
      and the first bad Monday then costs the feature its credibility instead of
      costing it one edit. The **Beta** badge stays — that one is honest.
- [ ] `lib/screens/suggestions/suggestion_info_sheet.dart` — new, behind the (i).
      The one-sentence explanation verbatim, the colour legend below, and the "what it
      will not handle" list. Plain language; no formulas.
- [ ] Date pill in `AppScaffold`'s `bottom` slot — the shared `DateSelector`
      (`lib/widgets/date_selector.dart`): calendar glyph, `Tue, 25 Aug 2026`, chevron.
      Defaults to today.
- [ ] Summary card — `StatBand`, two columns split by a hairline:
      **Orders Suggested** `16 / 18 shops` · **Total Value** `₹24,680` with
      `↑ 8% vs yesterday` beneath in `positive`. Definitions, which must not drift:
      numerator = shops that will get an order if Create is pressed right now;
      denominator = active shops; Total Value = sum of `suggestedValue`;
      *vs yesterday* compares against the **previous delivery day's actual order
      value**, not against yesterday's suggestion. Every ₹ figure renders through doc
      10a's currency formatter — there is no literal `₹` in this screen's source.
- [ ] `FilterChipRow` with live counts — `All Shops 18` · `Needs Review 2` ·
      `No Order 1`. The active chip takes the `brandPrimary` soft fill, which is doc
      10a's designated use for gold: emphasis, not meaning. **Default to Needs Review**
      when its count is greater than zero, else All Shops.
- [ ] `SectionHeader` reading `Review Changes` with the sparkle glyph, on the Needs
      Review filter only.
- [ ] `lib/widgets/suggestion_shop_card.dart` — new, and the only new widget in this
      release. An expandable `AppCard` composing `LetterAvatar`
      (`lib/widgets/letter_avatar.dart`), shop name over area, a `DeltaPill`, an
      expand chevron, `MiniTable` and `NoteBanner`. Cards are **expanded on Needs
      Review, collapsed on All Shops**, and each is wrapped in a `RepaintBoundary`.
- [ ] `DeltaPill` polarity: `+₹240` in `negative`, `−₹120` in `positive`. **Red is
      up, and the pill must be told so explicitly rather than inferring from sign.**
      On this screen the delta is a production change, not revenue — red means "bake
      more than usual", which is the direction that costs money if the suggestion is
      wrong. Doc 10a's rule that semantic colour is never decorative is what makes
      this legible, and it is also what makes the collision real: the `StatBand`'s
      `↑ 8%` is green because there it genuinely *is* growth. Two opposite conventions
      on one screen will be misread, so the legend behind the (i) is not optional, and
      `DeltaPill` gains a `polarity` parameter rather than a second widget.
- [ ] `MiniTable` columns: **Item · Usual Qty · Suggested · Change**. Numerics right
      aligned in a straight column; Change coloured to match the pill convention.
- [ ] `NoteBanner` for the reason line — doc 10a's `info` / `infoSoft` pair, which is
      the lavender in the mock and is defined there for exactly this: "reasons, hints,
      explanations". One line, from the fixed enum.
- [ ] Two `AppButton`s in a row: filled `brandDeep` **Use Suggested**, outlined
      **Edit Order**.
- [ ] **Use Suggested** marks the shop accepted and collapses the card. It writes
      nothing.
- [ ] **Edit Order** pushes `/order/:shopId?date=…` with the suggested quantities as
      a prefill. `lib/screens/order_entry/order_entry_screen.dart` gains an optional
      prefill argument; [doc 08](08-order-entry-swipe.md)'s swipe-by-5 applies
      normally. If the owner saves there, the shop **drops out** of the createable set
      on return and its card reads "Order already entered" — the order exists, and
      Create must never touch it.
- [ ] **Skip** — overflow action on the card. Excludes the shop and decrements the
      CTA count.
- [ ] Bottom CTA, a full-width `AppButton` in `brandPrimary`: **Create All Orders
      (16)** with the subtitle *Review before sending* and a trailing chevron, pinned
      above the nav bar. Disabled at a count of zero.
- [ ] Create writes N orders in **one transaction** via
      `orderDao.upsertOrderWithLines`, with `isConfirmed = false`. After that they
      are ordinary orders: **no `source` column, no badge, no special status
      anywhere.** An order the owner accepted is a decision the owner made, and
      marking it forever as machine-originated would need a schema change and a
      backup round-trip to buy nothing.
- [ ] Empty states via `EmptyState`, which doc 10a requires to carry an action: no
      active shops; no history at all (a fresh install after
      [doc 02](02-shipped-data-fix.md)); every shop already ordered for this date.
      "Nothing to suggest" with no next step is the failure doc 10a named.
- [ ] Loading via `AppSkeleton`, not a bare spinner.

### Tests

`test/suggestion_test.dart` — new. This changes what gets baked, so it gets the same
grade of coverage as FIFO allocation in [doc 05](05-ledger-foundation.md).

- [ ] A seeded fixture of **8 weeks × 18 shops × ~12 products** with deliberate
      structure: one shop with a strong Monday peak, one on a clean upward trend, one
      flat, one that dropped a product three weeks ago, one created last week, and
      one with no standing orders.
- [ ] Median arithmetic on a hand-checked shop: four Mondays of `10, 20, 20, 30` →
      base 20, not 20 by luck of the mean.
- [ ] Trend clamp: a shop that tripled in two weeks is suggested at most `1.15 ×
      base`, never triple.
- [ ] Standing-order clamp: no suggestion anywhere in the fixture falls outside
      `[0.5 ×, 2 ×] defaultQty` where a standing order exists.
- [ ] Rounding: `19 → 19`, `21 → 20`, `23 → 25`.
- [ ] Cold start: each of the six rows in the table above produces exactly the stated
      `confidence` and `reasonCode`.
- [ ] A product the shop has never ordered never appears, even with a standing order
      present for it.
- [ ] Every generated line has a `reasonCode`; assert the enum is exhaustively
      covered by the fixture.
- [ ] Needs Review triage: on the fixture, the count is between 1 and 5 of 18.
- [ ] **Held-out week accuracy** — train on weeks 1–7, predict week 8, compare to
      what was actually ordered. Both the suggestion's mean absolute error and the
      standing order's are computed; the assertion is on the ratio, not on an
      absolute figure.
- [ ] Purity: the whole suite runs against
      `lib/services/order_suggestion_service.dart` with no database.

## Success criteria

- [ ] On the held-out week of the fixture, the suggestion's mean absolute error per
      line is at least **20% lower** than the standing order's on the same lines. If
      it is not, this feature is not worth shipping and the algorithm goes back.
- [ ] At least **70%** of held-out lines land within **±2 units or ±15%**, whichever
      is larger.
- [ ] **100%** of suggested lines carry a reason string from the fixed enum. Zero
      lines render an empty or placeholder reason.
- [ ] No suggestion in the fixture exceeds `2 × defaultQty` or falls below
      `0.5 × defaultQty` where a standing order exists.
- [ ] No product a shop has never ordered appears in any suggestion.
- [ ] A shop that already has an order for the chosen date never appears in the
      createable count, and pressing Create leaves that order byte-identical.
- [ ] Pressing **Create All Orders (16)** writes exactly 16 `daily_orders` rows and
      the matching `order_lines`, and no other row in the database changes. Pressing
      it a second time writes nothing.
- [ ] Accepting, editing and skipping every shop without pressing Create leaves the
      database **completely unchanged** — verified by row counts before and after,
      not by inspection.
- [ ] Suggestions for 18 shops over 8 weeks of history compute in under **500 ms**
      and in **at most 3 queries**, verified by query log, not by feel.
- [ ] **Needs Review** surfaces between 1 and 5 shops on the real dataset on a normal
      weekday. Eighteen means the thresholds are wrong.
- [ ] Entering a full morning's orders through this screen takes under **3 minutes**,
      measured once on the owner's real data against the current 20–25. This is the
      only criterion that says whether the feature was worth building.

## Notes

- **The Beta pill comes off when the accuracy criterion holds on real data for four
  consecutive weeks**, not when the screen looks finished. It is a statement about
  the numbers, not decoration.
- The thresholds in the confidence rule are the first thing that will need changing.
  Keep them together and keep them named.
- Nothing here needs `backup_service.dart` touched — a rarity in this roadmap. It is
  a consequence of storing nothing, and it is a reason to keep storing nothing.
- If a "why did it suggest this" screen is ever wanted beyond the one-line reason,
  the honest version is a `MiniTable` of the four same-weekday observations that
  produced the base. Not built now; it is one query and one kit component when it is
  wanted.
- This screen is the first real consumer of doc 10a's kit outside
  [10c](10c-screen-restyle.md). If half of it ends up as private widgets in
  `auto_suggestions_screen.dart`, the kit did not work and that is worth knowing
  before eight more screens are built on it.
