# v4 Requirements — Phased Implementation Plan

## Context

`docs/v4-requirements` (verbal, captured in this conversation) lists eight improvements for Milano Orders — messaging quality, categorisation, catalog polish, a new dashboard, and a shop-wise ledger. Exploration confirmed:

- Kitchen share (`lib/screens/kitchen/kitchen_screen.dart:134-206`) currently uses `padRight` for alignment (breaks in WhatsApp's proportional font) and jams all products of a shop into one comma-separated line.
- Daily Billing share (`lib/screens/orders/orders_screen.dart:216-243`) uses the same `padRight` approach. The on-screen shop row (`_OrderCard`, `orders_screen.dart:279-389`) puts shop name and amount on one line — long shop names wrap under large accessibility font settings, reducing card density.
- Alphabetical ordering is nowhere. Kitchen sorts by qty desc; bills use DB insertion order.
- `Products` table (`lib/database/tables/products.dart`) has **no** `category` column. There is no `Categories` table.
- Catalog share (`lib/services/catalog_share_service.dart`) offers PDF / Image / Text formats. PDF is plain B&W A4 with a small logo and single-line product rows; Image renders the same PDF to PNG.
- No "Dashboard" concept exists. Home tab is a shops list; Kitchen tab is production aggregate; Orders tab is Daily Billing.
- No ledger, no payments, no bill status beyond `DailyOrders.isConfirmed` boolean.
- Existing plan docs (`docs/v2-implementation-plan.md`, `docs/v3-UI-IMPLEMENTATION-PLAN.md`) follow a phased shipping model with per-phase Action Items / Success Criteria.

Decisions confirmed with the user:

- **Phasing model**: One big roadmap, six sequential releases (v1.2 → v1.7). Each phase ships as its own `pubspec` version bump, cutting a GitHub Release automatically.
- **Message channel**: Kitchen and bill messages are read on WhatsApp. Column-padded text won't work — layout must be emoji + one-item-per-line instead.
- **Categories**: exactly one, optional (nullable FK). Delete = warn + orphan (set NULL). Emoji auto-picked from a fixed lookup table — no per-category emoji field. Seed 5 defaults on upgrade; existing products stay uncategorised.
- **PDF style**: menu-card look — cover page, category sections with emoji, product cards with photos in a 2-column grid, brand accent colors, page numbers + phone footer.
- **Image catalog**: removed (button + code).
- **Text catalog**: kept, but re-formatted to mirror PDF grouping/emojis.
- **Dashboard**: replaces Home tab. The centre-docked FAB (currently a snackbar `+`) becomes a Home icon that navigates to the (old) shops-list screen.
- **Time range control** on Dashboard: `Today · This Week · Last Week · This Month · Last Month · Last 90 Days · Custom`.
- **Bill identity**: no invoice number. A bill is identified by shop + date.
- **Payment model**: partial payments allowed, one payment can settle many bills, capture mode + note, one-way accounts receivable.
- **Opening balance**: per-shop field (amount + cutoff date), entered once at ledger launch.
- **Ledger access**: from Shops list → tap shop → View Ledger.
- **Record payment**: shop-level FAB with FIFO auto-allocation and an advanced manual-allocation panel.
- **Daily Billing hook**: payment status chip on each row + Mark-Paid quick action.
- **Statement export**: PDF only, per date range.

## Assumed defaults (explicit — flag if wrong)

- **Emoji lookup table** (case-insensitive whole-word match on category name): `Puffs → 🥟, Rolls → 🌯, Buns → 🍞, Cakes → 🍰, Cookies → 🍪, Bread → 🥖, Sweets → 🍬, Snacks → 🥨, Beverages → ☕`; fallback for unknown names → `🍽️`.
- **Inside-category ordering** in kitchen message and PDF = alphabetical by product name.
- **Single-shop bill share** (per-order share button) mirrors kitchen-message style: emoji header, alphabetical items, `· Bun × 30 — ₹150` per line, no column padding.
- **Payment chip semantics**: `Paid` green · `Partial` amber · `Unpaid` red.
- **Charts library**: `fl_chart` (well-maintained, no native deps, ~150-250 KB APK impact).
- **Manual allocation panel** (Record Payment): included in Phase 5 but time-boxed — if it slips, ship FIFO-only in v1.6 and land manual override as v1.6.1.

---

## Phase 1 — v1.2 · Quick fixes & polish

**Scope: points 2, 3 (non-category parts), 6.**

Small, self-contained cleanups. No schema changes, no new deps.

**Action items:**

- [ ] `lib/screens/profile/products/catalog_share_picker_screen.dart` — remove the `ListTile('Share as Image')` in the format bottom sheet (lines 36-45 area).
- [ ] `lib/services/catalog_share_service.dart` — delete `_buildImagePdfBytes(...)`, `shareCatalogAsImage(...)`, the `_kRowHeight` / `_kImageWidth` constants, and the `CatalogShareFormat.image` enum member. Remove now-dead imports (`printing.Printing.raster`, temp dir writes) if unused.
- [ ] `lib/screens/orders/orders_screen.dart` — refactor `_OrderCard` (lines 279-389): line 1 = full-width shop name + area; line 2 = right-aligned amount + Confirmed/Pending chip + share icon + expand arrow. Removes wrap-explosion at 130% system font.
- [ ] `lib/screens/orders/orders_screen.dart` — rewrite `_shareAll` (lines 216-243): drop `padRight` columns; emit `🏪 {shop} — ₹{amount}` per shop on its own line; a blank line then a bold-styled `GRAND TOTAL: ₹{grand}` at bottom.
- [ ] `lib/screens/orders/orders_screen.dart` — rewrite `_buildBillText` (lines 245-276): emoji header `🧾 Bill — {shop}`; date line; alphabetical items as `· {name} × {qty} — ₹{lineTotal}`; blank line; `TOTAL: ₹{total}`.
- [ ] `lib/screens/kitchen/kitchen_screen.dart` — in `_share()` (lines 134-206), switch the ITEM TOTALS section from `qty desc` to alphabetical by product name (`compareTo` with `toLowerCase()`).
- [ ] `lib/screens/kitchen/kitchen_screen.dart` — in `_ByItemView` (lines 234-316), switch the on-screen list from `qty desc` to alphabetical.
- [ ] `lib/screens/order_entry/order_entry_screen.dart` — after `_products` is loaded in `_init()`, sort alphabetically by name before `setState`.

**Tasks:**

1. Remove image catalog (picker + service + enum).
2. Rework Daily Billing on-screen row to two-line layout.
3. Rewrite `_shareAll`, `_buildBillText`, kitchen `_share` ITEM TOTALS section to emoji + alphabetical format.
4. Sort on-screen Kitchen By-Item and Order Entry product lists alphabetically.
5. Manual QA on device at 100 %, 130 %, and 200 % system font.

**Success criteria:**

- [ ] `grep -R "shareCatalogAsImage\|_buildImagePdfBytes\|CatalogShareFormat.image" lib/` returns no matches.
- [ ] Daily Billing shows ≥ 4 shop cards on screen at 130 % system font on a 6-inch phone.
- [ ] "Share All Bills" and single-bill share previews are readable on WhatsApp without monospaced font.
- [ ] Kitchen By-Item on-screen list and Order Entry product list are alphabetical.
- [ ] Kitchen share message ITEM TOTALS section is alphabetical.

---

## Phase 2 — v1.3 · Categories + Kitchen message overhaul

**Scope: point 4, point 1 (full), point 3 (category-tied parts).**

The heaviest schema change of the roadmap. Also the biggest UX shift for the kitchen team.

**Action items:**

- [ ] `lib/database/tables/categories.dart` — new table: `id INT PK autoIncrement`, `name TEXT UNIQUE NOT NULL`, `sortOrder INT DEFAULT 0`, `isActive BOOL DEFAULT true`.
- [ ] `lib/database/tables/products.dart` — add `IntColumn get categoryId => integer().nullable().references(Categories, #id)()`. `ON DELETE SET NULL` behaviour enforced in DAO (Drift doesn't emit SQL-level FK cascades by default).
- [ ] `lib/database/app_database.dart` — bump `schemaVersion` to `4`. In `migration.onUpgrade`, add: `if (from < 4) { m.createTable(categories); m.addColumn(products, products.categoryId); /* seed 5 defaults */ }`.
- [ ] `lib/database/seed_data.dart` — extract "seed 5 default categories" into a reusable function called from both fresh-install seed and the v3→v4 upgrade step. Defaults: Puffs, Rolls, Buns, Cakes, Cookies (in that `sortOrder`).
- [ ] `lib/services/category_emoji.dart` — new file, pure-Dart lookup: `String emojiFor(String? categoryName)`. Case-insensitive, whole-word match; fallback `🍽️`.
- [ ] `lib/database/daos/category_dao.dart` — new DAO: `watchActive`, `insert`, `rename`, `reorder`, `setActive`, `delete` (which first nulls-out `products.categoryId` where matched, then deletes the row).
- [ ] `lib/screens/profile/categories/category_list_screen.dart` — new: drag-to-reorder list, add/edit dialogs, delete-with-warning showing count of affected products.
- [ ] `lib/screens/profile/profile_screen.dart` — add "Categories" settings tile above Products.
- [ ] `lib/screens/profile/products/product_form_screen.dart` — add a `DropdownButtonFormField<int?>` for Category, with `null` = "Uncategorised" + list of active categories.
- [ ] `lib/screens/profile/products/product_list_screen.dart` — filter chips row at top (`All / {emoji} {category} / …`). Chip visible only if at least one category exists. No grouped headers — flat list within selected filter.
- [ ] `lib/screens/kitchen/kitchen_screen.dart` — rewrite `_share()`:
  - Header: `🍞 Kitchen List — {date}`.
  - **ITEM TOTALS** grouped by category: for each category (in sort order), `{emoji} {Category} (total: N pcs)` header; alphabetical items under, `· {name} × {qty}`. Final `🍽️ Others` group for uncategorised products.
  - **SHOP-WISE** shops sorted by `area ASC NULLS LAST, name ASC`. For each shop: `🏪 {shop} — {area}` header; alphabetical items, one per line `· {name} × {qty}`. **No category grouping in this section** (per your decision).
  - Footer: `Total: {N} shops · {M} pieces`.
- [ ] `lib/screens/kitchen/kitchen_screen.dart` — `_ByShopView` reorder to `area, name`.
- [ ] `lib/services/backup_service.dart` — extend export/import to include the new `categories` table and the `categoryId` field on products.

**Tasks:**

1. Author `Categories` table, migration v3→v4, seed defaults.
2. Author `CategoryDao` and `category_emoji` lookup service.
3. Build Categories management screen (CRUD, reorder, delete-with-warning).
4. Wire category dropdown into Product form, filter chips into Product list.
5. Rewrite kitchen share message; reorder By-Shop on-screen view.
6. Extend backup service to cover new schema.
7. Migration test: v3 install → upgrade → run app → verify all products preserved, all 5 default categories present, no orphan errors.
8. Manual QA of full kitchen message on WhatsApp with real data.

**Success criteria:**

- [ ] Fresh install has 5 default categories present in the expected order.
- [ ] Upgrading a v3 install preserves every shop, product, order, price, and standing order; category column defaults to NULL.
- [ ] Deleting a category with N products shows `"N products will become uncategorised. Continue?"`; on confirm, the products become uncategorised and the category is removed.
- [ ] Product list filter chips filter correctly; "Uncategorised" chip also works.
- [ ] Kitchen share ITEM TOTALS section has emoji category headers with correct per-category totals; items alphabetical inside each; uncategorised appear under `🍽️ Others`.
- [ ] Kitchen share SHOP-WISE section is ordered by area then name; each shop's items are one-per-line, alphabetical.
- [ ] Backup file exported from v1.3 imports cleanly into another v1.3 install with categories preserved.

---

## Phase 3 — v1.4 · Catalog PDF redesign

**Scope: point 5, plus text-share mirror.**

Depends on Phase 2 (categories drive PDF sections).

**Action items:**

- [ ] `lib/services/catalog_share_service.dart` — rebuild `_buildPdfBytes(...)` using `pw.MultiPage`:
  - **Cover page** — logo centred (~120 px), business name (brand-brown, `bold`, size 22), address + phone (grey, size 10), italic `"Product Catalog"` in gold accent, current date as `"Prices valid as of {date}"`.
  - **Content pages** — one section per category (in sort order). Section header: gold accent horizontal bar + `{emoji} {Category}` in brown, `bold`, size 16. Products laid out as a **2-column grid of cards**: 100×100 photo (or coloured letter-avatar placeholder for products with no photo); product name (bold); category label (small grey); unit (small grey); price (brand-brown, right-aligned). Uncategorised products under a final `🍽️ Others` section.
  - **Every content page footer**: thin gold rule; `{business.name} · ☎ {phone}   ·   Page X of Y`.
- [ ] `lib/services/catalog_share_service.dart` — rewrite `_buildCatalogText(...)` to mirror the PDF grouping: category header lines with emojis, alphabetical items, `Category: unit — ₹price` per line.
- [ ] `lib/services/catalog_share_service.dart` — delete the image-catalog helpers already stripped in Phase 1 (should already be gone; sanity check).
- [ ] `lib/screens/profile/products/catalog_share_picker_screen.dart` — picker now only shows PDF and Text. No behavioural change needed beyond Phase 1's removal.

**Tasks:**

1. Author cover-page widget.
2. Author category section widget (accent bar + emoji header).
3. Author product-card widget (100×100 photo cell with letter-avatar fallback, name, category, unit, price).
4. Wire `pw.MultiPage` with header (cover page only, per Drift's existing pattern) and footer (page number + phone on every page).
5. Rewrite text share to mirror grouping.
6. Manual QA — export PDF with 20 products across 4 categories, verify cover, sections, grid, footer, uncategorised handling.

**Success criteria:**

- [ ] Generated PDF cover page shows logo, business name, address, phone, and today's date.
- [ ] Categories appear in the same order as the Categories screen; alphabetical products inside each; uncategorised products land in a final `🍽️ Others` section.
- [ ] Products with no photo show a coloured letter-avatar (not an empty grey box).
- [ ] Every content page footer shows business name, phone, and `Page X of Y`.
- [ ] Text share, opened in WhatsApp, shows category groups with emojis and alphabetical items.
- [ ] Image-catalog code path is confirmed gone (`grep` clean, sanity re-check from Phase 1).

---

## Phase 4 — v1.5 · Dashboard

**Scope: point 7.**

Depends on Phase 2 (kitchen category-wise donut) but NOT on Phase 5 (ledger) — sales dashboard ships revenue-only; Outstanding card is deferred to Phase 6.

**Action items:**

- [ ] `pubspec.yaml` — add `fl_chart: ^0.68.0`.
- [ ] `lib/screens/home/home_screen.dart` — rename current file/class to `home_shops_screen.dart` / `HomeShopsScreen`; keep the file's current content (shops list). Register under route `/home/shops`.
- [ ] `lib/screens/dashboard/dashboard_screen.dart` — new file. Riverpod-driven, top-level `SingleChildScrollView` of cards.
- [ ] `lib/app.dart` — swap the Home branch's first route from `HomeScreen` to `DashboardScreen`. Add `/home/shops` inside the same branch. Change the centre-docked FAB from the current snackbar `+` (`_ScaffoldWithNavBar.build`, `app.dart:252-263`) to a Home icon that calls `context.go('/home/shops')`. Keep the FAB visible on all four top-level tabs.
- [ ] `lib/providers/dashboard_provider.dart` — new file:
  - `dashboardRangeProvider` (`StateProvider<DashboardRange>`), with presets `today, thisWeek, lastWeek, thisMonth, lastMonth, last90, custom`.
  - `kitchenDailyTotalsProvider(range)` — `List<({DateTime date, int pieces})>`.
  - `kitchenCategoryBreakdownProvider(range)` — `List<({int? categoryId, String name, int pieces})>`.
  - `salesRevenueSummaryProvider` — `({double today, double wtd, double mtd})`.
  - `salesDailyRevenueProvider(range)` — `List<({DateTime date, double revenue})>`.
  - `salesTopShopsProvider(range)` — `List<({int shopId, String name, double revenue})>` (top 5).
  - `salesTopProductsProvider(range)` — `List<({int productId, String name, double revenue})>` (top 5).
- [ ] `lib/database/daos/dashboard_dao.dart` — new DAO backing the providers with grouped aggregations.
- [ ] `lib/widgets/dashboard/date_range_pill.dart` — segmented pill: `Today · This Week · Last Week · This Month · Last Month · Last 90 Days · Custom`. On "Custom" tap → `showDateRangePicker`.
- [ ] `lib/widgets/dashboard/kitchen_section.dart` — cards:
  1. Today's total production (hero number) + `Confirmed X / Pending Y shops` subtitle.
  2. Top 5 items today — horizontal bar list.
  3. Category-wise donut for selected range (`fl_chart PieChart`, `centerSpaceRadius` for donut hole).
  4. 7-day trend line for total pieces (`fl_chart LineChart`).
- [ ] `lib/widgets/dashboard/sales_section.dart` — cards:
  1. 3-number strip: Today's revenue · WTD · MTD.
  2. Top shops by revenue (bar list) · Top products by revenue (bar list).
  3. 30-day revenue trend (`fl_chart LineChart` or `BarChart`).

**Deferred to Phase 6**: Sales dashboard "Outstanding Receivables" card (needs Ledger).

**Tasks:**

1. Add `fl_chart` dependency.
2. Rename `HomeScreen` → `HomeShopsScreen`; register new `/home/shops` route.
3. Build `DashboardScreen` shell + date-range pill.
4. Author `DashboardDao` and dashboard providers.
5. Build Kitchen section cards.
6. Build Sales section cards.
7. Rewire centre-docked FAB to navigate to `/home/shops`.
8. Handle empty-state gracefully (zero orders in range).
9. Manual QA at each range preset with seeded + real data.

**Success criteria:**

- [ ] Home tab renders Dashboard with all 7 cards (4 Kitchen + 3 Sales).
- [ ] Centre-docked FAB shows a Home icon; tapping navigates to the shops list; back button returns to Dashboard.
- [ ] Changing the date-range pill updates every card in one animation frame (no stale values).
- [ ] Empty state (no orders in selected range) shows friendly card placeholders, not errors or crashed charts.
- [ ] Charts render correctly at 30-day scale with real data density.

---

## Phase 5 — v1.6 · Ledger foundation

**Scope: point 8 (except Daily-Billing hook, PDF statement, Dashboard outstanding — those go to Phase 6).**

Second heavyweight schema change. Backup service must be extended in lockstep.

**Action items:**

- [ ] `lib/database/tables/payments.dart` — new: `id PK`, `shopId FK → Shops`, `paidAt DateTime`, `amount Real`, `mode TEXT` (`cash / upi / bank / cheque`), `note TEXT nullable`.
- [ ] `lib/database/tables/payment_allocations.dart` — new: `paymentId FK → Payments`, `orderId FK → DailyOrders`, `amount Real`, primary key = `{paymentId, orderId}`.
- [ ] `lib/database/tables/shops.dart` — add `openingBalance Real nullable` (interpreted as 0 when null) and `openingBalanceAt DateTime nullable` (cutoff date; bills before this date are considered pre-ledger and are excluded from ledger view).
- [ ] `lib/database/app_database.dart` — bump `schemaVersion` to `5`. In `onUpgrade`, add `if (from < 5) { m.createTable(payments); m.createTable(paymentAllocations); m.addColumn(shops, shops.openingBalance); m.addColumn(shops, shops.openingBalanceAt); }`.
- [ ] `lib/database/daos/ledger_dao.dart` — new DAO:
  - `Stream<List<LedgerEntry>> watchShopLedger(shopId, {DateTimeRange? range, LedgerStatus? status, LedgerType? type})` — chronological interleave of bills (debits) and payments (credits) with running balance computed in-Dart.
  - `Stream<ShopLedgerStats> watchShopStats(shopId)` — `totalBilled`, `totalCollected`, `outstanding`, `lastPaymentAt`.
  - `Future<BillStatus> getBillStatus(orderId)` — derives Paid/Partial/Unpaid from `sum(payment_allocations.amount) vs order total`.
  - `Future<int> recordPayment({required int shopId, required double amount, required PaymentMode mode, String? note, List<AllocationInput>? allocations})` — if `allocations` is null, auto-allocate FIFO to oldest unpaid bills of that shop (respecting cutoff date). Returns new payment ID.
  - `Future<void> deletePayment(int paymentId)` — cascades allocations.
- [ ] `lib/providers/ledger_provider.dart` — new: `shopLedgerProvider.family`, `shopStatsProvider.family`, `billStatusProvider.family` (for use in Phase 6's Daily Billing chip).
- [ ] `lib/screens/profile/shops/shop_form_screen.dart` — add "Opening Balance" (numeric, optional) and "As of Date" (date picker, defaults to today). Only editable on new shop or when opening balance is currently null (prevent accidental rewriting of history).
- [ ] `lib/screens/profile/shops/shop_list_screen.dart` — add "View Ledger" action to each row (trailing menu or extra IconButton).
- [ ] `lib/screens/ledger/shop_ledger_screen.dart` — new:
  - App bar: shop name + area.
  - Stats header: `Total Billed · Total Collected · Outstanding · Last Payment`.
  - Filter row: date-range picker · Status chips (`All · Unpaid · Partial · Paid`) · Type chips (`All · Bills · Payments`).
  - Chronological list — each row: date, description (`Bill · {date}` or `Payment · {mode}`), amount (Dr in red, Cr in green), running balance column.
  - FAB: **Record Payment**.
- [ ] `lib/screens/ledger/record_payment_sheet.dart` — modal bottom sheet: amount (required), mode selector (Cash / UPI / Bank / Cheque), note (optional). Below, an "Advanced: choose allocation" expandable section listing the shop's unpaid/partial bills with editable amount fields; if unopened, allocation is FIFO auto. Save button validates that `sum(allocations) == amount`.
- [ ] `lib/services/backup_service.dart` — extend export/import to cover `payments`, `paymentAllocations`, and the new `shops` columns.

**Tasks:**

1. Author new tables + schema v4→v5 migration.
2. Author `LedgerDao` with running-balance and status derivations.
3. Extend Shop form with opening balance + cutoff date.
4. Build Shop Ledger screen (stats + filters + list).
5. Build Record Payment sheet (FIFO default + manual allocation panel).
6. Wire ledger providers.
7. Extend backup service.
8. Migration test: v4 install → upgrade → run app → verify all data preserved, opening balance = null for existing shops.
9. Load test: seed 500+ bills and 100+ payments for one shop; verify ledger screen renders and scrolls smoothly.

**Success criteria:**

- [ ] Upgrading a v4 install preserves all data. Opening balance defaults to null (interpreted as 0) for existing shops.
- [ ] Recording a ₹5,000 shop-level payment (auto FIFO) correctly settles the oldest unpaid bills first — verified against a fixture of 4 bills totalling ₹5,200 (last bill left partial at ₹200).
- [ ] Advanced allocation panel: manually splitting ₹5,000 across 3 chosen bills validates the sum before Save enables.
- [ ] Ledger screen with 500 entries renders and scrolls smoothly (no jank at 60 fps on a mid-range device).
- [ ] Status filter and date-range filter combine correctly (e.g., `Unpaid` + last 30 days).
- [ ] Backup file exported from v1.6 imports cleanly into another v1.6 install with all payments and allocations preserved.

---

## Phase 6 — v1.7 · Ledger integration + statements

**Scope: point 2 (payment chip), point 8 (remaining: Daily-Billing hook, PDF statement, Dashboard Outstanding card).**

Ties everything together. No new schema.

**Action items:**

- [ ] `lib/screens/orders/orders_screen.dart` — `_OrderCard` gains a second chip (below the amount or beside Confirmed): `Paid` (green) / `Partial` (amber) / `Unpaid` (red), driven by `billStatusProvider.family(orderId)`. Chip reacts in real time as payments are recorded elsewhere.
- [ ] `lib/screens/orders/orders_screen.dart` — kebab or long-press on `_OrderCard` → context menu with "Mark as Paid" → opens a small variant of the Record Payment sheet, pre-filled with amount = bill total and allocation pre-locked to this bill. Creates a Payment + single allocation.
- [ ] `lib/services/ledger_statement_service.dart` — new service using `pw.MultiPage`. Reuses the brand accent styling from Phase 3 catalog PDF.
  - Header (cover-style, top of first page): shop name + area, business info, period label (`Statement · {from} → {to}`).
  - Table: date, description, Dr, Cr, running balance.
  - Summary block at end: `Opening balance · Total Billed · Total Collected · Closing balance`.
  - Every page footer: `{business.name} · ☎ {phone}   ·   Page X of Y` — same style as catalog.
  - Shared via `Printing.sharePdf`.
- [ ] `lib/screens/ledger/shop_ledger_screen.dart` — app bar action: "Export Statement" → date-range picker → generates PDF via the new service.
- [ ] `lib/widgets/dashboard/sales_section.dart` — add "Outstanding Receivables" card: sum of all shops' outstanding balances. Tap → new "Shops with Outstanding" screen listing shops ordered by outstanding desc, each row navigating into its ledger.
- [ ] `lib/screens/ledger/outstanding_list_screen.dart` — new lightweight screen backing the Dashboard tap.

**Tasks:**

1. Add payment status chip to Daily Billing rows.
2. Add "Mark as Paid" quick action from Daily Billing.
3. Author `ledger_statement_service` (reuse styling from Phase 3).
4. Wire "Export Statement" action in Shop Ledger.
5. Add "Outstanding Receivables" card to Sales Dashboard + shop-listing screen.
6. Reconciliation QA: spot-check a shop with 20+ bills and 5+ payments — app numbers vs. PDF vs. Dashboard outstanding must all agree.

**Success criteria:**

- [ ] Payment status chip on Daily Billing row is accurate for every shop and updates without app restart when a payment is recorded elsewhere.
- [ ] Mark-as-Paid from Daily Billing appears in that shop's ledger as a payment with the correct mode and amount.
- [ ] PDF statement for a shop's month reconciles exactly with the on-screen ledger for the same period.
- [ ] Sales Dashboard "Outstanding Receivables" total equals the sum of all shops' individual outstandings (verify via SQL or fixture test).
- [ ] Tapping the Outstanding card lands on the shops-with-outstanding list, ordered highest first.

---

## Cross-phase risks & considerations

- **Three-hop schema migration** (`v3 → v4 → v5`). Before shipping v1.3 and v1.6, run the full upgrade chain end-to-end against a v3 install with real data. Recommend adding `drift_dev`'s schema-snapshot tests for at least the two migration hops.
- **Backup/restore compatibility**. `lib/services/backup_service.dart` must be extended in the same commit that adds new tables/columns (Phase 2 for categories; Phase 5 for payments + shop opening balance). A backup from an older app version must fail-safe when imported into a newer app — reject with a friendly error, don't silently drop fields.
- **`fl_chart` APK size**. Expect ~150-250 KB added in Phase 4. Acceptable given the universal APK strategy.
- **Manual allocation UX (Phase 5)** — the advanced allocation panel is the most complex piece in this roadmap. Time-box it. If it slips, ship FIFO-only in v1.6 and land the manual override as v1.6.1 with the following patch scope: add expandable panel + sum-validation + save-guard.
- **Payment editing / deletion**. Not in initial scope. If a payment was recorded incorrectly, the fix is "delete and re-record". Deletion cascades allocations and restores outstanding balance on the affected bills. If experience shows this is too destructive, revisit in v1.8.
- **Kitchen message length on WhatsApp**. Category-grouped messages will get longer than today's. If it exceeds WhatsApp's single-message limit (~4,000 chars), fall back to splitting into two messages (ITEM TOTALS in one, SHOP-WISE in another) or, alternatively, offer a PDF export of the kitchen list. Not in Phase 2 scope; watch and revisit.
- **Emoji rendering on older Android devices** — pre-Android 10 devices may render `🥟` (dumpling) as `☐`. Not a correctness issue; document in the release notes as a known cosmetic limitation.

---

## Version summary

| Version | Phase | Headline |
|---|---|---|
| v1.2 | 1 | Quick fixes: image catalog removed, bill message polish, alphabetical lists, Daily Billing row density |
| v1.3 | 2 | Categories + kitchen message overhaul |
| v1.4 | 3 | Catalog PDF redesign (menu-card style) |
| v1.5 | 4 | Dashboard replaces Home tab (Kitchen + Sales cards) |
| v1.6 | 5 | Ledger foundation (payments, opening balance, shop ledger screen, record payment) |
| v1.7 | 6 | Ledger integration (payment chip on Daily Billing, PDF statement, Outstanding on Dashboard) |
