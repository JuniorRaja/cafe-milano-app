# 07 — Ledger: statements, billing chip & outstanding

| | |
|---|---|
| **Target version** | `1.9.0+11` |
| **Type** | Feature |
| **Schema** | No change |
| **Requires** | [05 — Ledger foundation](05-ledger-foundation.md) |
| **Status** | Ready |

## Why

Docs 05 and 06 make the ledger correct. This one makes it *reachable* — from the
screens the owner already uses daily, and from the shop's side of the conversation.

Three connections, none of which need new data:

1. **Daily Billing shows payment status.** The billing screen is opened every day.
   Right now it shows what each shop owes and nothing about what they have paid.
2. **A shop can be sent its statement.** "You still owe ₹8,400" is an argument.
   A dated statement showing every bill and every payment with a running balance is
   a document. The app already generates a menu-card catalogue PDF, so the styling
   and the share path both exist.
3. **The dashboard shows total receivables.** Cash owed across all shops is a headline
   business number and is currently nowhere in the app.

## Action items

### Payment status on Daily Billing

- [ ] `lib/screens/orders/orders_screen.dart` — `_OrderCard` gains a second chip:
      **Paid** (green) / **Partial** (amber) / **Unpaid** (red), driven by
      `billStatusProvider.family(orderId)` from doc 05.
- [ ] The chip must update in real time when a payment is recorded elsewhere, without
      an app restart — it is a Drift stream, so this comes free if the provider is
      watched rather than read once. Verify it rather than assuming it.
- [ ] Watch the query count here. This is a list, and a naive per-row provider is an
      N+1 of exactly the kind doc 04 removed from the dashboard. Fetch statuses for
      all visible orders in **one** query keyed by date, then look up per row.
- [ ] Long-press or kebab on `_OrderCard` → **Mark as Paid**. Opens the record-payment
      sheet pre-filled with amount = this bill's residual and allocation locked to
      this bill. This is the single most common real-world action — a shop pays its
      bill in full on the day — and it should take two taps, not a trip through the
      ledger screen.

### PDF statement

- [ ] `lib/services/ledger_statement_service.dart` — new, using `pw.MultiPage`. Reuse
      the brand accent styling already established by the catalogue PDF in
      `lib/services/catalog_share_service.dart`; do not invent a second visual language.
  - Header: shop name + area, business info, period label (`Statement · {from} → {to}`).
  - Table: date · description · Dr · Cr · running balance.
  - Summary block: **Opening balance · Total Billed · Total Collected · Closing balance**.
  - Page footer: `{business.name} · ☎ {phone}  ·  Page X of Y`.
  - Share via `Printing.sharePdf`.
- [ ] The statement is going to a shop over WhatsApp. It must be readable on a phone
      screen, not just correct on A4 — check column widths at phone zoom before
      calling it done.
- [ ] Long statements must page cleanly: no row split across a page break, header
      repeated on every page.
- [ ] `lib/screens/ledger/shop_ledger_screen.dart` — app bar action **Export
      Statement** → date-range picker → generate and share.

### Outstanding receivables

- [ ] `lib/widgets/dashboard/outstanding_card.dart` — new dashboard section showing
      the summed outstanding across all shops. One aggregate query, not one per shop.
- [ ] `lib/screens/profile/dashboard_settings_screen.dart` — add its visibility toggle,
      matching how the other dashboard sections are controlled.
- [ ] `lib/screens/ledger/outstanding_list_screen.dart` — new. Shops ordered by
      outstanding descending, each row tapping through to that shop's ledger. Reached
      by tapping the dashboard card.
- [ ] Decide what "outstanding" includes at the edges and state it on the screen:
      opening balances are in; bills before each shop's cutoff are out; unallocated
      credits reduce it. Ambiguity here is what makes two screens disagree.

### Reconciliation

- [ ] The three surfaces — ledger screen, PDF statement, dashboard total — are three
      independent computations of the same money. Add a test asserting they agree on
      a seeded fixture, and spot-check by hand on a shop with 20+ bills and 5+
      payments including one partial and one multi-bill payment.

## Success criteria

- [ ] Payment status chip is correct for every shop on the billing screen, and updates
      live when a payment is recorded from the ledger without restarting the app.
- [ ] The billing screen issues a fixed number of queries regardless of shop count.
- [ ] Mark-as-Paid from Daily Billing creates a payment that appears in that shop's
      ledger with the right amount, mode and date, and flips the chip to Paid.
- [ ] A month's PDF statement reconciles **exactly** with the on-screen ledger for the
      same period — opening, billed, collected and closing all match to the paisa.
- [ ] A statement spanning 3+ pages repeats headers and splits no row.
- [ ] The statement is legible on a phone screen at default zoom.
- [ ] Dashboard "Outstanding Receivables" equals the sum of every shop's individual
      outstanding, verified against a direct SQL query — not by eye.
- [ ] Tapping the card lands on the outstanding list, ordered highest first, and each
      row opens the right ledger.
- [ ] A shop with zero outstanding does not appear in the outstanding list.
