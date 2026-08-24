# 05 — Ledger: payments & running balance

| | |
|---|---|
| **Target version** | `1.7.0+9` |
| **Type** | Feature |
| **Schema** | v5 → v6 |
| **Requires** | [03 — FK enforcement + indexes](03-db-integrity.md) |
| **Followed by** | [06 — Manual allocation](06-ledger-manual-allocation.md), [07 — Statements & outstanding](07-ledger-statements.md) |
| **Status** | Ready |

## Why

The app tracks production and billing. It does not track **collection**. Today the
only payment-related state in the database is `DailyOrders.isConfirmed`, a boolean
that means "the order is agreed", not "the money arrived".

What actually happens in the business:

- A shop is billed for a day's delivery.
- It may pay that same day, the next day, or later.
- It may pay **partially** — ₹3,000 against a ₹5,000 bill.
- It may pay **one lump sum covering several days' bills at once**.
- It pays by cash or UPI. The mode is worth recording, but nothing branches on it.

So the data model cannot be a `paidAmount` column on the order. A payment does not
belong to one bill. It belongs to the shop, and it is *allocated* across bills. That
allocation is the whole design.

**Explicitly out of scope: payment processing.** No gateway, no UPI intent, no
reconciliation against a bank feed. The owner records what was received. This is a
bookkeeping feature, not a payments feature.

This doc ships the foundation with **FIFO auto-allocation only** — a payment settles
the oldest unpaid bills first. Manual "apply this payment to these specific bills"
is [doc 06](06-ledger-manual-allocation.md), deliberately split out because it is the
fiddliest part and the least urgent.

## Data model

Two new tables plus two columns on `Shops`.

```
Payments
  id           INT PK autoincrement
  shopId       INT FK → Shops
  paidAt       DATETIME
  amount       REAL
  mode         TEXT        -- cash | upi | bank | cheque
  note         TEXT NULL

PaymentAllocations
  paymentId    INT FK → Payments
  orderId      INT FK → DailyOrders
  amount       REAL
  PRIMARY KEY (paymentId, orderId)

Shops
  + openingBalance    REAL NULL      -- treated as 0 when null
  + openingBalanceAt  DATETIME NULL  -- cutoff; bills before this are pre-ledger
```

Three things to hold onto:

- **A payment is never stored against a single bill.** `Payments.shopId` is the only
  link to the business entity; `PaymentAllocations` distributes the amount. A payment
  covering four days is one `Payments` row and four `PaymentAllocations` rows.
- **Bill status is derived, never stored.** `sum(allocations for order) vs order
  total` → Paid / Partial / Unpaid. There is no status column to drift out of sync.
- **The opening balance handles pre-ledger history.** Shops already owe money on the
  day this feature ships. `openingBalance` is what they owed as of
  `openingBalanceAt`; bills dated before the cutoff are excluded from the ledger view
  so the balance is not double-counted.

An allocation may legitimately not sum to the payment. A shop can overpay, or pay in
advance. Doc 06 decides how that surfaces; here, FIFO simply stops allocating when it
runs out of unpaid bills, and the remainder sits as an unallocated credit.

### Starting from existing history

On the day this ships, every bill already in the database reads Unpaid, because no
payments have ever been recorded. That is alarming but not wrong — it is just an
un-reconciled ledger.

The intended fix is **not** the opening balance. It is a single **catch-up payment**
per shop: record one payment for everything that shop has already paid, and FIFO
settles the oldest bills automatically until it runs out. The shop's Outstanding
then equals the owner's handwritten figure.

> Shop billed ₹50,000 to date. Notebook says ₹8,400 still owed.
> Record one ₹41,600 payment, noted "Opening catch-up".
> → Eight bills settle, the ninth goes Partial, Outstanding reads ₹8,400.

Which individual bills FIFO marks as settled will not match reality bill-by-bill —
but the **balance** is exact, and the balance is the number the business runs on.
Reconstructing a year of bill-level payment history is not worth anyone's evening.

`openingBalance` therefore stays for the case it was designed for: a shop whose
pre-ledger bills are not in this database at all. If the bills are in the database,
use a catch-up payment instead, and leave the opening balance null.

## Action items

### Schema

- [x] `lib/database/tables/payments.dart` — new, per the model above. `mode` as a
      `TextColumn`, not an enum column; the four values are a UI concern.
- [x] `lib/database/tables/payment_allocations.dart` — new, composite PK
      `{paymentId, orderId}`.
- [x] `lib/database/tables/shops.dart` — add `openingBalance`, `openingBalanceAt`,
      both nullable.
- [x] `lib/database/app_database.dart` — `schemaVersion = 6`; in `onUpgrade`:
      ```dart
      if (from < 6) {
        await m.createTable(payments);
        await m.createTable(paymentAllocations);
        await m.addColumn(shops, shops.openingBalance);
        await m.addColumn(shops, shops.openingBalanceAt);
      }
      ```
- [x] Index `payment_allocations(orderId)` and `payments(shopId, paidAt)` in the same
      migration — the status derivation hits the first on every billing row, and the
      ledger hits the second on every open. Follows the pattern set in doc 03.
- [x] With FK enforcement now on (doc 03), deleting a payment must delete its
      allocations **first**, in a transaction. There is no `ON DELETE CASCADE` in this
      schema by decision.
- [x] `lib/services/backup_service.dart` — extend export **and** import for
      `payments`, `paymentAllocations`, and the two new `Shops` columns.
      **Same commit.** This is the third time the roadmap says it; it is the most
      frequently missed step in this codebase, and here it carries money.
- [x] `lib/database/daos/backup_dao.dart` — add the two tables to `restoreAll`'s
      wipe sequence, ordered so allocations are deleted before payments and before
      orders.

### DAO

`lib/database/daos/ledger_dao.dart` — new.

- [x] `Stream<List<LedgerEntry>> watchShopLedger(shopId, {DateTime? rangeStart, DateTime? rangeEnd, BillStatus? status, LedgerType? type})`
      — chronological interleave of bills (debits) and payments (credits), running
      balance computed in Dart. Opening balance seeds the running total as the first
      entry when set. (Takes plain `DateTime` start/end rather than a `DateTimeRange`
      — matches doc 04's `DashboardDao`, which keeps `flutter/material.dart` out of
      the database layer; `DateTimeRange` is unpacked at the provider layer instead.)
- [x] `Stream<ShopLedgerStats> watchShopStats(shopId)` — `totalBilled`,
      `totalCollected`, `outstanding`, `lastPaymentAt`.
- [x] `Future<BillStatus> getBillStatus(orderId)` — derives Paid / Partial / Unpaid.
      Consumed by doc 07's billing chip; build it here so the derivation lives in one
      place from the start.
- [x] `Future<int> recordPayment({required int shopId, required double amount, required DateTime paidAt, required PaymentMode mode, String? note})`
      — inserts the payment, then auto-allocates **FIFO** against that shop's oldest
      unpaid or partially-paid bills, respecting `openingBalanceAt`. Whole thing in
      one transaction. Returns the new payment id.
- [x] `Future<void> deletePayment(int paymentId)` — allocations then payment, one
      transaction. Editing a payment is **not** in scope; the correction path is
      delete and re-record. Revisit only if that proves too blunt in practice.
- [x] Money comparisons must tolerate floating-point error. `REAL` columns mean
      `sum(allocations) == orderTotal` can be false by 1e-13. Compare with a
      **1-paisa epsilon** (`< 0.005`), everywhere, without exception. Write this as a
      single shared helper so it cannot be done inconsistently — this is the most
      likely source of a bill that displays as Partial forever with ₹0.00 outstanding.

### Providers

- [x] `lib/providers/ledger_provider.dart` — `shopLedgerProvider.family`,
      `shopStatsProvider.family`, `billStatusProvider.family`.
- [x] Follow doc 04's lessons: no N+1, no duplicate aggregate across providers, plain
      `get()` where a stream is not needed. (`watchShopLedger` and `watchShopStats`
      are each a single reactive `customSelect`, not N+1 per-row queries.)

### UI

- [x] `lib/screens/ledger/shop_ledger_screen.dart` — new. **Two tabs**, added after
      first real use: the single chronological statement was accurate but unreadable —
      it answered "what happened" when the owner was asking "who owes me what".
  - App bar: shop name + area.
  - Stats header (above both tabs): **Total Billed · Total Collected · Outstanding ·
    Last Payment**.
  - **Outstanding tab** (default): only bills still owing, oldest first, under a
    banner reading `N pending bills · ₹X due · oldest Nd`. No filters — this tab
    answers exactly one question.
  - **History tab**: the chronological ledger — rows of date · type
    (`Bill` / `Payment · {mode}`) · amount (Dr red, Cr green) · running balance.
  - Row layout on both tabs leads with the **date and its status badge on one
    line**, with bill total / amount paid / age as a secondary line. The badge sits
    beside the date rather than under the description: status and date are what the
    eye scans a collections list for, so they belong on the same line.
  - Zero-total orders never render as bills. Opening the order-entry screen calls
    `getOrCreateOrder`, so a shop accumulates empty order rows that are not bills;
    they are skipped when building the ledger (contributing 0.0, they cannot shift
    the running balance) and `getBillStatus` derives them as Paid, not Unpaid.
  - FAB: **Record Payment**.
- [x] Filters live behind a **bottom sheet**, not inline chips. Three rows of chips
      (date · 4 status · 3 type) pushed the list off the screen and read as clutter.
      The History tab now shows one `Filters (N)` button, a plain-language summary of
      what is active (`Bills · Unpaid · 24 Jul – 23 Aug`), and a clear button. The
      sheet groups Date range / Status / Type with Reset and Apply, and edits a draft
      so nothing re-queries until Apply.
- [x] Payment rows on the History tab carry a delete action (icon, and long-press),
      confirming before it runs. Editing a payment stays out of scope as decided
      below, but with no delete in the UI the documented correction path did not
      actually exist — the DAO method was unreachable. The dialog states plainly that
      settled bills return to unpaid and that correcting means delete-and-re-record.
- [x] `lib/screens/ledger/record_payment_sheet.dart` — new modal bottom sheet.
      Amount (required), mode selector (Cash / UPI / Bank / Cheque), note (optional),
      date defaulting to today but editable — payments get entered a day late, which
      is the whole point of the feature. Save runs FIFO allocation.
      Leave a clearly marked seam where doc 06 adds the allocation panel.
      Shows the shop's current Outstanding with a **Settle full** shortcut that fills
      the amount — one tap for the common "paid the whole thing" case, and the figure
      you subtract from for a catch-up entry.
- [x] `lib/screens/profile/shops/shop_form_screen.dart` — "Opening Balance" (numeric,
      optional) and "As of Date". Editable only on a new shop, or while
      `openingBalance` is still null. Once set it is history and must not be
      silently rewritten.
- [x] `lib/screens/profile/shops/shop_list_screen.dart` — "View Ledger" action per row.
- [x] Empty states: a shop with no bills and no payments, and a shop with bills but no
      payments, must both read sensibly. After doc 02 a fresh install has no data at
      all, so these are reachable on day one.

### Tests

- [x] `test/ledger_test.dart` — new. FIFO allocation is the one piece of this
      roadmap that silently mis-states money, so it gets real coverage:
  - ₹5,000 across four bills totalling ₹5,200 → first three settled, fourth partial
    at ₹200 outstanding.
  - Payment larger than all outstanding bills → remainder unallocated, not negative.
  - Payment against a shop with zero unpaid bills → payment persists, no allocations.
  - Bills before `openingBalanceAt` are never allocated against.
  - Delete a payment → outstanding returns exactly to its prior value.
  - The epsilon: a bill paid to the last paisa reads Paid, not Partial.
  - Plus: a second payment closing Partial → Paid, one payment spanning four days'
    bills, an out-of-order-inserted past-dated payment sorting correctly, the
    running-balance identity, and status+date filters combined. `test/backup_test.dart`
    also gained a payments/allocations/opening-balance round-trip case.
  - The catch-up path above: ten ₹5,000 bills, one ₹41,600 payment → Outstanding
    lands exactly on ₹8,400, two bills stay open (one Partial at ₹3,400, one Unpaid
    at ₹5,000), and the open bills' dues sum to the same ₹8,400.
  - `allocatedAmount` / `amountDue` are correct per bill, and zero on payment rows.

## Success criteria

- [ ] Upgrading a real v5 install preserves all data; `openingBalance` is null for
      every existing shop and reads as ₹0. **Not verified here** — this environment
      has no Flutter/Dart SDK to run a real migration or `flutter test` against a
      device database. The `onUpgrade` `from < 6` block follows the exact same
      `createTable`/`addColumn` shape already proven by the v2–v5 migrations in the
      same file; still, run this against a real pre-v6 device backup before release.
- [x] Recording a ₹5,000 payment against a fixture of four bills totalling ₹5,200
      settles the oldest three and leaves the fourth partial at ₹200.
- [x] A partial payment leaves the bill Partial with the correct residual, and a
      second payment closes it to Paid.
- [x] One payment spanning four days' bills appears once in the ledger and correctly
      reduces the balance of all four.
- [x] Payments dated to a past day land in the correct chronological position with a
      correct running balance.
- [x] Bills before the opening-balance cutoff never appear in the ledger and are never
      allocated against.
- [x] Running balance at the bottom of the ledger equals
      `openingBalance + totalBilled − totalCollected`, exactly.
- [x] Deleting a payment restores every affected bill's status and the shop's
      outstanding to their prior values.
- [ ] Ledger with 500 entries scrolls at 60 fps on a mid-range device. **Not
      verified** — no device/SDK available in this environment to profile against.
- [x] Status filter and date filter combine correctly (`Unpaid` + last 30 days).
- [x] Backup exported from `1.7.0` re-imports into `1.7.0` with every payment and
      allocation preserved, and outstanding figures identical before and after.
