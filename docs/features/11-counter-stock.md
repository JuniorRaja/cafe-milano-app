# 11 — Counter stock (Cafe Milano only)

| | |
|---|---|
| **Target version** | `1.13.0+15` |
| **Type** | Feature |
| **Schema** | v7 → v8 |
| **Status** | **Outline** — expand action items before starting |

## Why

Product-wise daily stock for shop #1, the owner's own counter. Two entry moments:
morning (opening + inward) and close (waste + closing). It is what turns "we sold
₹X" into "we made 200, sold 170, wasted 30" — sell-through and waste, the two numbers
that change what gets baked tomorrow.

Decision taken 2026-08-19, not reopened: **Cafe Milano counter only**, finished goods.

**Known ceiling, stated plainly:** tracking only shop #1 means product-level insight is
limited to one outlet's sell-through and waste. The other 17 shops yield order and
revenue insight only — no returns, no sell-through. Revisit only if those outlets ever
agree to report, which they have not.

## Data model

```
CounterStock
  stockDate  DATETIME     -- normalised to midnight
  productId  INT FK → Products
  opening    INT DEFAULT 0
  inward     INT DEFAULT 0
  waste      INT DEFAULT 0
  closing    INT DEFAULT 0
  PRIMARY KEY (stockDate, productId)
```

Two rules that are easy to get backwards:

- **Sold is derived, never stored**: `opening + inward − waste − closing`.
- **Carry-over is stored, not computed**: on first open of a date, prefill `opening`
  from the previous day's `closing` **and persist it**. If it were computed, correcting
  a past day would silently rewrite every subsequent day's opening. Stored means
  history stays immutable.

## Outline of work

- `lib/database/tables/counter_stock.dart` — new, per above.
- `lib/database/app_database.dart` — `schemaVersion = 8`, create the table.
- `lib/services/backup_service.dart` — extend for `counterStock`, **same commit**.
- `lib/database/daos/stock_dao.dart` — `watchStockForDate(date)`,
  `upsertStockLine(...)`, `getPreviousClosing(date, productId)`,
  `watchStockRange(from, to)` for reports.
- `lib/screens/counter/counter_stock_screen.dart` — reuses the shared `DateSelector`
  and `selectedDateProvider`. One row per product, four inline numeric cells, derived
  Sold read-only at the row end. If [doc 08](08-order-entry-swipe.md) has shipped, the
  swipe-by-5 gesture applies to the focused cell.
- Day summary bar: total produced · total sold · total waste · waste %.
- **Negative-sold guard**: if `opening + inward − waste − closing < 0`, flag the row
  amber inline. Do **not** block saving. The staff member's count is the fact; a
  blocked save just means they stop using the app and go back to paper.
- Decide whether counter stock rows for shop #1 interact with its orders at all. The
  recommendation is **no** — they are independent records, and reconciling them is a
  reporting question for [doc 12](12-dashboard-tabs.md), not a write-time coupling.
- `test/` — the derivation arithmetic and the carry-over rule. This carries real
  counts; it gets tests.

## Success criteria

- [ ] Entering a full 28-product closing count takes under 90 seconds.
- [ ] Yesterday's closing appears as today's opening with no user action.
- [ ] Editing a past day's closing does **not** silently rewrite subsequent days'
      openings.
- [ ] Waste % matches a hand calculation on a seeded fixture week.
- [ ] A negative-sold row flags amber and still saves.
- [ ] A v7 backup imports into v8 cleanly, and a v8 backup round-trips with stock intact.
