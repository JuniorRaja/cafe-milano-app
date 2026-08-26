# 06 — Ledger: manual allocation

| | |
|---|---|
| **Target version** | `1.9.0+13` |
| **Type** | Feature |
| **Schema** | No change |
| **Requires** | [05 — Ledger foundation](05-ledger-foundation.md) |
| **Status** | Ready |

## Why

Doc 05 allocates every payment FIFO — oldest unpaid bill first. That is right most
of the time and wrong some of the time:

- The shop says "this ₹2,000 is for Tuesday's delivery", skipping an older disputed bill.
- An older bill is under dispute and should stay open while newer ones are settled.
- The owner is reconciling against the shop's own records, which are not FIFO.

Without an override, the only way to express any of that is to delete the payment and
re-record it — which does not help, because re-recording runs FIFO again.

This is split from doc 05 deliberately. The archived v4 plan flagged this panel as
the most complex piece in the whole ledger and recommended time-boxing it. Making it
its own release means doc 05 ships and gets used while this is built, and if it turns
out to be more work than expected, nothing else is blocked.

## Scope

An expandable **Advanced: choose allocation** section inside the existing record-payment
sheet. Closed by default. Closed means FIFO, exactly as doc 05 behaves today — so the
common path is untouched and gains no extra taps.

Opened, it lists the shop's unpaid and partially-paid bills with an editable amount
field per bill, and validates before allowing save.

## Action items

- [ ] `lib/screens/ledger/record_payment_sheet.dart` — expandable section below the
      existing fields, using the seam left by doc 05. Collapsed by default.
- [ ] Rows list each open bill: date, bill total, already-allocated, residual, and an
      editable amount field pre-filled with what FIFO **would** have assigned. So
      opening the panel and changing nothing produces exactly the FIFO result — the
      panel starts from the default rather than from blank, which is both less typing
      and a way to see what FIFO was going to do.
- [ ] Live running footer: **Allocated ₹X of ₹Y · ₹Z unallocated**. Updates per
      keystroke.
- [ ] Validation, with **Save disabled** and the reason shown, when:
  - any row's amount exceeds that bill's residual;
  - any amount is negative;
  - the total allocated exceeds the payment amount.
- [ ] Allocating **less** than the payment total is **allowed** — that is an advance
      or an on-account credit, and it is a real thing shops do. The unallocated
      remainder must be visible in the footer, and must show in the shop's ledger as
      a credit that reduces the running balance. Do not block this; do not silently
      absorb it either.
- [ ] `ledger_dao.dart` — extend `recordPayment` with an optional
      `List<AllocationInput>? allocations`. Null keeps today's FIFO path untouched.
      Non-null skips FIFO entirely and writes exactly what is given, inside the same
      transaction. Re-validate server-side in the DAO — the UI check is a convenience,
      not the guarantee.
- [ ] Reuse doc 05's shared paisa-epsilon helper for every comparison here. Do not
      introduce a second tolerance rule.
- [ ] A "clear / reset to FIFO" affordance, so someone who has edited themselves into
      a mess can get back to the default without closing the sheet.
- [ ] Keyboard handling: with the panel open on a shop with many open bills, the sheet
      is tall and every row has a numeric field. The focused field must stay visible
      above the keyboard. This is the part most likely to feel broken on a real phone.
- [ ] `test/ledger_test.dart` — extend:
  - manual split of ₹5,000 across three chosen bills, skipping an older one, leaves
    the skipped bill fully unpaid;
  - over-allocating a single bill beyond its residual is rejected at the DAO;
  - partial allocation leaves the correct unallocated credit and the correct balance;
  - opening the panel and saving without edits produces byte-identical allocations to
    the FIFO path.

## Success criteria

- [ ] Leaving the panel closed produces the same result as `1.7.0` in every case.
- [ ] Opening the panel and saving unchanged produces the same allocations as FIFO.
- [ ] Splitting ₹5,000 across three chosen bills validates the sum before Save enables,
      and writes exactly those three allocations.
- [ ] Skipping an older bill leaves it Unpaid while newer bills settle.
- [ ] Allocating ₹4,000 of a ₹5,000 payment succeeds, shows ₹1,000 unallocated, and the
      shop's outstanding drops by the full ₹5,000.
- [ ] Over-allocating a bill is rejected in the UI **and** at the DAO if called directly.
- [ ] A shop with 20 open bills renders the panel without jank, and the focused field
      stays above the keyboard throughout.
- [ ] Ledger, statement and outstanding figures reconcile after a manually allocated
      payment exactly as they do after a FIFO one.
