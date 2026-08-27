# 09 — Exclude shops from the grand total

| | |
|---|---|
| **Target version** | `1.12.0+16` |
| **Type** | Feature |
| **Schema** | v6 → v7 |
| **Requires** | Nothing (independent of the ledger) |
| **Status** | Ready |

## Why

Not every shop in the list is an external customer. Shop #1 is Cafe Milano itself —
the owner's own counter. Its "orders" are stock moved to their own shelf, not revenue
from a third party. Including it in the daily grand total and in dashboard revenue
overstates both.

The same applies to any internal transfer or sample delivery the owner wants tracked
as production but not counted as a sale.

One nullable-free boolean, defaulting true so nothing changes for existing shops
until the owner says otherwise.

Carried forward from the archived v5 roadmap Phase 1, split out here as its own
release because it is a data-model change with no relationship to the swipe gesture
it was originally bundled with.

## Interaction with the ledger

If docs 05–07 have shipped, this needs a decision, and it should be made
deliberately rather than falling out of the implementation:

**An excluded shop still has a ledger.** Excluding a shop from the *grand total* is a
statement about revenue reporting, not about whether the shop owes money. Cafe
Milano's own counter does not owe itself anything, but a "samples" shop might still
be invoiced.

Recommended: `countInTotal` affects **only** the Daily Billing grand total and
dashboard revenue aggregates. It does **not** touch ledger balances, outstanding
receivables, or statements. Those are driven by bills and payments, which are
unaffected. State this on the settings switch so the behaviour is not a surprise.

## Action items

- [ ] `lib/database/tables/shops.dart` — add
      `BoolColumn get countInTotal => boolean().withDefault(const Constant(true))();`
- [ ] `lib/database/app_database.dart` — `schemaVersion = 7`;
      `if (from < 7) await m.addColumn(shops, shops.countInTotal);`
      Existing shops default to true, so upgrading changes no number.
- [ ] `lib/services/backup_service.dart` — export and import the new column, **same
      commit**. An older backup restoring into this version must default it to true,
      not to false or null.
- [ ] `lib/screens/profile/shops/shop_form_screen.dart` — "Include in daily grand
      total" switch, default on, with one line of explanatory text covering the ledger
      interaction above.
- [ ] `lib/screens/orders/orders_screen.dart` — the grand total sums only shops where
      `countInTotal` is true. Excluded rows **still appear** and still show their own
      amount, with a muted "not counted" marker. Hiding them would lose the production
      information the row exists for.
- [ ] `lib/providers/dashboard_provider.dart` + `lib/database/daos/dashboard_dao.dart`
      — revenue aggregates respect `countInTotal`. Work through each one; this touches
      more queries than it first appears:
      revenue-for-date, category scores, shop concentration, product leaderboard,
      revenue mix, attention flags.
- [ ] Decide and apply consistently whether **piece counts** (kitchen production
      totals) are also filtered. They should **not** be — the kitchen still has to bake
      those items regardless of who is billed for them. Only money is filtered. Write
      this down next to the flag's definition, because it is the kind of thing that
      gets silently reversed six months later.
- [ ] Shop concentration and "inactive shop" attention flags: an excluded shop should
      not appear in either. It is not a concentration risk and its inactivity is not a
      business signal.

## Success criteria

- [ ] A real v6 install upgrades with `countInTotal` true for every existing shop, and
      **every displayed figure is identical** before and after the upgrade.
- [ ] Excluding a shop reduces the Daily Billing grand total by exactly that shop's
      amount, and no more.
- [ ] Excluding a shop reduces dashboard revenue for any range containing its orders
      by exactly that shop's contribution.
- [ ] The excluded shop's row still shows on Daily Billing with its own total and a
      "not counted" marker.
- [ ] Kitchen production totals are **unchanged** when a shop is excluded.
- [ ] An excluded shop does not appear in shop concentration or in inactive-shop flags.
- [ ] If the ledger has shipped: excluding a shop leaves its ledger, outstanding and
      statements completely unchanged.
- [ ] A v6 backup imports into v7 with `countInTotal` defaulting true for all shops.
