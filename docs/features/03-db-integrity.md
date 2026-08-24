# 03 — Foreign key enforcement + indexes

| | |
|---|---|
| **Target version** | `1.6.1+7` |
| **Type** | Fix |
| **Schema** | v4 → v5 |
| **Blocks** | [05 — Ledger foundation](05-ledger-foundation.md) |
| **Status** | Ready |

## Why

Two database-layer defects that are invisible today and expensive later. Both must
be fixed **before** the ledger lands, because the ledger introduces
`payment_allocations` — rows whose only meaning is the payment and order they point
at, and whose corruption is corruption of money.

### 1. Foreign keys are declared but never enforced

Every table uses `.references(...)`:

```dart
IntColumn get shopId => integer().references(Shops, #id)();   // daily_orders
IntColumn get orderId => integer().references(DailyOrders, #id)();  // order_lines
```

SQLite ignores foreign keys unless `PRAGMA foreign_keys = ON` is set **per
connection**. There is no `beforeOpen` in `lib/database/app_database.dart` — so the
constraints exist in the schema DDL and are enforced by nothing at runtime.

The app currently compensates in the UI, incompletely:

| Delete | Guarded against | **Not** guarded against |
|---|---|---|
| Shop (`shop_form_screen.dart:56`) | has orders | `shop_prices`, `standing_orders` |
| Product (`product_form_screen.dart:106`) | has order lines | `shop_prices`, `standing_orders` |
| Category (`category_dao.dart:45`) | — nulls `products.categoryId` first, correct | — |

So deleting a shop that has prices and standing orders but no orders succeeds and
silently orphans those rows. Nothing surfaces; the rows simply become unreachable
garbage that the price matrix and standing-order screens still count.

### 2. No indexes exist anywhere

Not one `CREATE INDEX` in the schema. Every dashboard aggregate is a full table
scan:

```sql
-- dashboard_dao.dart:11 — full scan of order_lines AND daily_orders
SELECT COALESCE(SUM(ol.qty * ol.unit_price), 0.0) FROM order_lines ol
INNER JOIN daily_orders o ON ol.order_id = o.id WHERE o.order_date = ?
```

At today's 95 orders / 506 lines this is genuinely free — do not expect a
measurable improvement now. The point is the trajectory: a year of real trading is
roughly 365 days × 18 shops ≈ 6,500 orders and ~40,000 lines, and the dashboard
fires around a dozen aggregates per load. Adding indexes costs one migration now
and is awkward to retrofit once the ledger doubles the query surface.

## Action items

### Foreign keys

- [ ] **Pre-flight first.** Before enabling anything, add a one-off diagnostic run
      of `PRAGMA foreign_key_check` against a copy of the real device database.
      Enforcement on a database that already contains orphans will fail at open.
      This must be checked against real data, not a seeded fixture.
- [ ] If orphans exist, clean them in the v4→v5 migration **before** enabling the
      pragma — delete orphaned `shop_prices`, `standing_orders`, `order_lines` rows
      whose parent is gone. Log the counts. Do not silently discard without a record.
- [ ] `lib/database/app_database.dart` — add to `MigrationStrategy`:
      ```dart
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
      ```
      It must be `beforeOpen`, not `onCreate`/`onUpgrade` — the pragma is per
      connection and resets every time the database is opened.
- [ ] Note the ordering constraint: the pragma must be **off** during the migration
      itself and on afterwards. Drift's `beforeOpen` runs after migrations, so the
      default ordering is already correct — but do not move the pragma into a
      migration step.
- [ ] Close the incomplete delete guards. Extend `shopHasOrders` /
      `productHasOrderLines` into a general "is this referenced anywhere" check
      covering `shop_prices` and `standing_orders` too, so the UI blocks the delete
      with a clear message rather than the database throwing a constraint error.
- [ ] Verify `backup_dao.dart:41-48` `restoreAll` still works with enforcement on.
      Its delete order (`order_lines` → `daily_orders` → `standing_orders` →
      `shop_prices` → `products` → `categories` → `shops` → `business_info`) is
      already FK-safe — but the **insert** order on restore must be checked too, and
      it is not obviously safe. This is the single most likely thing to break.
- [ ] Decide and record: no `ON DELETE CASCADE` anywhere. Deletion is blocked at
      the UI, and both `Shops` and `Products` already carry `isActive` for the
      soft-delete path the app actually wants. Cascade on financial data is a way to
      lose records quietly.

### Indexes

- [ ] `lib/database/app_database.dart` — bump `schemaVersion` to `5`, add
      `if (from < 5) { ... }` creating four indexes:

      | Index | Column(s) | Serves |
      |---|---|---|
      | `idx_daily_orders_date` | `daily_orders(order_date)` | every dashboard date filter, kitchen, billing |
      | `idx_daily_orders_shop` | `daily_orders(shop_id)` | per-shop history; the ledger in doc 05 |
      | `idx_order_lines_order` | `order_lines(order_id)` | every join from lines to orders |
      | `idx_order_lines_product` | `order_lines(product_id)` | product leaderboard, category rollups |

- [ ] Consider `daily_orders(order_date, shop_id)` as a composite instead of two
      single-column indexes — most queries filter date then group by shop. Check the
      actual query shapes in `dashboard_dao.dart` before choosing; do not add both.
- [ ] Verify with `EXPLAIN QUERY PLAN` on the heaviest dashboard query that the
      index is actually used. An index the planner ignores is pure write overhead.
- [ ] `lib/services/backup_service.dart` — **no change needed** for indexes (they
      carry no data), but re-run the round-trip test anyway. This file is the
      recurring trap in this codebase; touching schema without checking it is how it
      drifts.

### Tests

- [ ] `test/dao_test.dart` — deleting a shop with dependent `shop_prices` is
      rejected, not silently orphaned.
- [ ] `test/backup_test.dart` — full export → wipe → import round-trip with
      enforcement on.

## Success criteria

- [ ] `PRAGMA foreign_keys` reports `1` on a live connection.
- [ ] `PRAGMA foreign_key_check` returns zero rows on the migrated real database.
- [ ] Attempting to delete a shop that has prices or standing orders is blocked in
      the UI with a clear message — and never reaches the database as an exception.
- [ ] Backup export → wipe → import round-trips cleanly with enforcement on, on the
      **real** dataset, not a fixture.
- [ ] A real v4 install upgrades to v5 with all data intact and no orphan cleanup
      surprises. Test against an actual pre-upgrade device database.
- [ ] `EXPLAIN QUERY PLAN` shows index usage on the revenue-for-date query.
- [ ] Dashboard behaviour is unchanged. This release must be invisible to the user —
      if anything looks different, something broke.
