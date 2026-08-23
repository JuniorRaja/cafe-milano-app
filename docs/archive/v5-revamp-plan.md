# v5 Revamp — UX, Modules & Cloud

Supersedes nothing. Phases 5–6 of `v4-implementation-plan.md` (ledger) are **reused verbatim**, re-sequenced as Phase 4 here.

## Context

Current: v1.5.0+5. Flutter + Drift (local SQLite, schema v4) + Riverpod + go_router. Single-user, offline, no auth.
Live data: 18 shops, 28 products, 212 shop prices, 329 standing orders, ~95 orders / 506 lines.

**Decisions taken (2026-08-19), do not re-litigate:**

| Question | Decision |
|---|---|
| Backend | Supabase, **online-only** (no offline sync layer) |
| Stock scope | **Cafe Milano counter only** (shop #1), finished goods |
| Roles | **Three tiers** — owner / manager / staff |
| Navigation | **Hybrid** — bottom nav for daily jobs, drawer for masters/reports/settings |
| Order entry | **Swipe-by-5 on a flat list** (no shortlist / "usual items" section) |
| Sequencing | **UX + features first on Drift, Supabase last** |

**Already done, not in scope:** font migration to Quicksand (`d9e6799`), signed-APK CI on version bump.

---

## Design principles (govern every phase)

Four rules, derived from the data rather than from articles:

1. **Recognition over recall.** 90% of quantities are multiples of 5, median 10. Every input affordance should make ±5 the cheapest gesture and typing the fallback, never the reverse.
2. **One decision per glance.** Only ~6 of 28 products carry a non-zero qty on an average order. Screens should not present 28 equally-weighted choices when 6 matter — expressed here through visual weight (zero-qty rows recede) rather than reordering, per the flat-list decision.
3. **Confirm by feel, not by dialog.** Haptics replace confirmation toasts for reversible actions. Dialogs are reserved for the genuinely destructive.
4. **Latency is UX.** Under online-only, every screen must have an explicit loading and an explicit offline state. A spinner with no timeout is a bug, not a state.

**Known ceiling of the stock decision:** tracking only shop #1 means the "product-level business insights" ambition is limited to one outlet's sell-through and waste. The other 17 shops yield order/revenue insight only — no returns, no sell-through. Revisit if the outlets ever agree to report.

---

## Phase 1 — v1.6 · Order entry rework + haptics

The highest-frequency pain: 15+ shops × ~6 products, daily.

**Schema:** v4 → v5 — `Shops.countInTotal BOOL DEFAULT TRUE`.

**Action items:**

- [ ] `lib/widgets/product_qty_row.dart` — wrap the row in a `GestureDetector` (`onHorizontalDragStart/Update/End`).
  - Accumulate drag pixels in the row's **own** `State`. Every 48 px crossed = ±5, clamped 0–9999.
  - Commit each crossing up to the parent via `onQtySet`; the per-frame translate/background stays local so the parent's 28-row `setState` fires ~once per 5 units, not per frame.
  - Reveal behind the row: green `+5` on right-drag, red `−5` on left-drag. Not `Dismissible` — that widget removes rows.
  - Vertical `ListView` scroll and horizontal drag do not conflict; no custom gesture-arena work needed.
- [ ] `lib/widgets/product_qty_row.dart` — `_StepperBtn` gains `onLongPress` → `Timer.periodic(150ms)` repeating ±5 until release. Cancel in `dispose`.
- [ ] Keep both existing paths intact: single-tap ±1 steppers, and tap-the-number → keyboard sheet. Swipe is additive.
- [ ] Unpriced products (currently `opacity 0.45`, callbacks null) reject swipe with `HapticFeedback.heavyImpact()` and no movement.
- [ ] Haptics pass — `selectionClick` on each 5-crossing (swipe and hold), `mediumImpact` on Confirm Order, `heavyImpact` on rejected input. `lightImpact` on ±1 already exists.
- [ ] Zero-qty rows render at reduced visual weight; non-zero rows get a filled qty chip. Principle 2 without reordering.
- [ ] `lib/database/tables/shops.dart` — add `countInTotal`. `app_database.dart` → `schemaVersion = 5`, `if (from < 5) m.addColumn(shops, shops.countInTotal)`.
- [ ] `lib/screens/profile/shops/shop_form_screen.dart` — "Include in daily grand total" switch, default on.
- [ ] `lib/screens/orders/orders_screen.dart` — grand total sums only `countInTotal` shops; excluded rows show a muted "not counted" marker and still display their own total.
- [ ] `lib/providers/dashboard_provider.dart` + `lib/database/daos/dashboard_dao.dart` — revenue aggregates respect `countInTotal`.
- [ ] `lib/services/backup_service.dart` — export/import the new column.

**Success criteria:**

- [ ] Entering a real 6-product order takes 6 swipes and zero keyboard.
- [ ] Drag stays at 60 fps on a mid-range Android with all 28 products loaded.
- [ ] Swiping left at qty 0 does nothing and does not go negative.
- [ ] Excluding a shop changes the Daily Billing grand total and the Dashboard revenue by exactly that shop's amount.
- [ ] A v4 backup imports into v1.6 with `countInTotal` defaulting true for all 18 shops.

---

## Phase 2 — v1.7 · Navigation + settings restructure

**No schema change.**

Bottom bar keeps only what is touched daily; everything configured monthly moves behind the drawer.

```
Bottom nav (FAB gap preserved):  Home · Billing  [ FAB → Dashboard ]  Kitchen · Counter
Drawer:  Dashboard
         MASTERS      Shops · Categories · Products · Price Matrix · Standing Orders
         REPORTS      (Phase 4)
         SETTINGS     Business Info · Dashboard · Backup & Restore · Users (Phase 5) · About
```

**Action items:**

- [ ] `lib/app.dart` — replace the Profile branch with a **Counter** branch (`/counter`; screen lands in Phase 3, ship a placeholder). Update `_topLevelPaths`.
- [ ] `lib/app.dart` — `_ScaffoldWithNavBar` gains a `Drawer`. Keep the FAB → Dashboard; it works and is daily-use for the owner.
- [ ] `lib/widgets/floating_nav_bar.dart` — swap the person icon for a counter/inventory icon. The 2 + gap + 2 layout is unchanged.
- [ ] `lib/widgets/app_drawer.dart` — new. Grouped sections, business name + logo header, version footer.
- [ ] `lib/screens/profile/profile_screen.dart` → `lib/screens/settings/settings_screen.dart`. Routes move `/profile/*` → `/settings/*`, with redirects from the old paths. Redesign per principle 1: grouped cards with section headers, a live-filter search field at the top (28+ destinations once Phases 3–5 land), and each tile showing a current-state summary rather than static prose — e.g. Shops → "18 active, 2 excluded from total"; Price Matrix → "212 of 504 prices set" and amber when incomplete; Backup → "last exported 3 days ago".
- [ ] `lib/providers/session_provider.dart` — new, one line: `currentRoleProvider` returns `AppRole.owner` hardcoded. Drawer and settings gate off it now; Phase 5 swaps the body for the real Supabase session. **No local login screen** — a fake auth built now would be thrown away in Phase 5.

**Success criteria:**

- [ ] Every route reachable before the change is still reachable, with redirects from `/profile/*`.
- [ ] Reaching any master takes at most 2 taps from any screen.
- [ ] Settings search filters to a destination in one keystroke.
- [ ] Back from a drawer destination returns to the originating tab, not to the drawer.

---

## Phase 3 — v1.8 · Counter stock (Cafe Milano only)

Product-wise daily stock for shop #1. Two entry moments: morning (opening + inward), close (waste + closing).

**Schema:** v5 → v6.

- [ ] `lib/database/tables/counter_stock.dart` — `stockDate DateTime`, `productId FK → Products`, `opening INT DEFAULT 0`, `inward INT DEFAULT 0`, `waste INT DEFAULT 0`, `closing INT DEFAULT 0`. PK `{stockDate, productId}`, date normalised to midnight.
- [ ] Sold is **derived, never stored**: `opening + inward − waste − closing`.
- [ ] Carry-over is **stored, not computed**: on first open of a date, prefill `opening` from the previous day's `closing` and persist it. History then stays immutable when a past day is later corrected.
- [ ] `lib/database/daos/stock_dao.dart` — `watchStockForDate(date)`, `upsertStockLine(...)`, `getPreviousClosing(date, productId)`, `watchStockRange(from, to)` for reports.
- [ ] `lib/screens/counter/counter_stock_screen.dart` — reuses the shared `DateSelector` and `selectedDateProvider`. One row per product, four inline numeric cells, derived Sold read-only at the row end. The Phase 1 swipe-by-5 gesture applies to the focused cell.
- [ ] Day summary bar: total produced · total sold · total waste · waste %.
- [ ] Negative-sold guard: if `opening + inward − waste − closing < 0`, flag the row amber inline. Do **not** block saving — the staff member's count is the fact, and a blocked save just means they stop using the app.
- [ ] `lib/services/backup_service.dart` — extend for `counterStock`.

**Success criteria:**

- [ ] Entering a full 28-product closing count takes under 90 seconds.
- [ ] Yesterday's closing appears as today's opening without any user action.
- [ ] Editing a past day's closing does not silently rewrite subsequent days' openings.
- [ ] Waste % matches a hand calculation on a seeded fixture week.
- [ ] A v5 backup imports into v1.8 cleanly.

---

## Phase 4 — v1.9 · Ledger + dashboard modules

**Ledger: build exactly `docs/v4-implementation-plan.md` Phase 5 and Phase 6, unchanged.** Payments, payment allocations, shop opening balance + cutoff date, FIFO auto-allocation, ledger screen, record-payment sheet, payment-status chip on Daily Billing, PDF statements, Outstanding Receivables. That spec is sound and complete; re-deriving it would waste a day.

**Schema:** v6 → v7 — as specified there (`payments`, `payment_allocations`, `shops.openingBalance`, `shops.openingBalanceAt`).

**Additional to that spec** — with stock and ledger data now present, the dashboard's single long scroll gets sub-navigation:

- [ ] `lib/screens/dashboard/dashboard_screen.dart` — a `TabBar` over four tabs. **Re-home the existing widgets; build no new charts:**
  - **Sales** — `PulseCard`, `RevenueMixCard`, `WeekdayHeatmapWidget`
  - **Products** — `CategoryScorecardsWidget`, `ProductLeaderboardCard`, plus a new counter waste / sell-through card (Phase 3 data)
  - **Shops** — `ShopConcentrationCard`, plus Outstanding Receivables (from v4 Phase 6)
  - **Alerts** — `AttentionFlagsWidget`
- [ ] `lib/providers/dashboard_settings_provider.dart` — per-tab visibility toggles replace the flat section list.
- [ ] Drawer **REPORTS** section becomes live: Daily Sales · Product Movement · Counter Stock · Shop Ledger · Outstanding.

**Success criteria:**

- [ ] All v4-plan Phase 5/6 success criteria, as written there.
- [ ] Each dashboard tab renders in under 400 ms on the real dataset.
- [ ] No dashboard widget is duplicated across tabs.

---

## Phase 5 — v2.0 · Supabase, auth & roles

The big one. Everything above ships on Drift first, then the data layer swaps underneath unchanged Riverpod providers.

**Action items:**

- [ ] Supabase project. Mirror schema v7 into Postgres — same table and column names, `int` PKs preserved (no UUID migration; nothing needs it).
- [ ] `profiles` table: `id UUID FK → auth.users`, `display_name`, `role TEXT CHECK (role IN ('owner','manager','staff'))`.
- [ ] **Disable public signup** in Supabase Auth settings. Users are created by hand in the dashboard. This is the CUG requirement — enforce it server-side, not in the app.
- [ ] RLS policies, per role:

| | orders / lines | billing + prices | ledger + payments | counter stock | kitchen list | masters + settings |
|---|---|---|---|---|---|---|
| **owner** | RW | RW | RW | RW | R | RW |
| **manager** | RW | RW | RW | RW | R | — |
| **staff** | — | — | — | RW | R | — |

- [ ] One-time import: `tool/import_to_supabase.dart`, reading the existing backup JSON export. Verify row counts per table before and after.
- [ ] Replace each DAO with a Supabase query module. **Provider signatures do not change** — screens stay untouched. Drift stays in `pubspec.yaml` until every DAO is ported, then goes.
- [ ] `lib/screens/auth/login_screen.dart` — email + password, no signup link, no in-app password reset (the owner resets from the dashboard).
- [ ] `lib/providers/session_provider.dart` — the Phase 2 hardcoded `owner` is replaced by the real session role. Every gate written in Phases 2–4 becomes real with no screen changes.
- [ ] Every screen gains explicit loading and **offline** states. Offline means an inline banner with a retry, never a silent empty list.

**The known risk of online-only, stated plainly:** order entry at 5 a.m. in a basement kitchen with no signal fails outright. The cheap mitigation, if it bites in practice, is a draft buffer on the order-entry screen only — hold unsaved quantities in `shared_preferences` (already a dependency) and flush on reconnect. Roughly 60 lines, one screen, no sync engine, no conflict resolution. Not built now; built the week it first hurts.

**Success criteria:**

- [ ] Row counts and financial totals match exactly, local vs Supabase, on the full imported dataset.
- [ ] A staff login cannot read prices, revenue or ledger — verified by querying those tables directly with the staff JWT, not just by checking that the UI hides them.
- [ ] Signup is impossible from the app and from a raw API call.
- [ ] Two devices editing different shops' orders concurrently both persist.
- [ ] Killing the network mid-order surfaces a visible error, never silent data loss.

---

## Phase 6 — v2.1 · Distribution, docs & test harness

- [ ] GitHub Pages site — a single static `index.html` that fetches `api.github.com/repos/JuniorRaja/cafe-milano-app/releases/latest` client-side and renders a download button. Public repo, so unauthenticated. No build step, no framework.
- [ ] In-app update check — same endpoint, compare the tag against the `package_info_plus` version on launch, show a dismissible prompt that opens the APK URL. Adds one dependency (`url_launcher`); check at most once per day.
- [ ] `AGENTS.md` — architecture map, data model, module boundaries, local setup, build and release procedure, and the conventions an agent must not break. `CLAUDE.md` keeps the working rules and links to it.
- [ ] `docs/testing-checklist.md` — a scripted device walkthrough per module, driven through `mobile-mcp` (already available in tooling): install APK → log in per role → order entry → kitchen → counter stock → billing → ledger → screenshot each. Not a unit-test framework; a repeatable smoke pass before each release.
- [ ] Extend `test/dao_test.dart` for the swipe-quantity clamp, the stock derivation arithmetic, and FIFO allocation. Those three carry real money or real counts — the rest of the UI does not need tests.

---

## Cross-phase risks

- **Three schema hops on Drift (v4→v5→v6→v7), then a platform migration.** Run the full upgrade chain against a real v4 install before shipping each of v1.6, v1.8 and v1.9. `drift_dev` schema-snapshot tests for each hop are worth the setup.
- **`backup_service.dart` is the recurring trap.** It must be extended in the *same commit* as any schema change — Phases 1, 3 and 4 each touch it. An older backup imported into a newer app must fail loudly, never silently drop columns. It is also the only bridge into Supabase in Phase 5: if it has drifted, the migration has no clean source.
- **Phase 5 touches every DAO.** Keeping provider signatures stable is what makes it survivable. If a screen has to change during the port, the port is being done wrong.
- **The Supabase anon key ships inside the APK.** That is normal and expected — RLS is the security boundary, not the key. The `service_role` key must never appear in the repo, in CI, or in the app.
- **Role gating written in Phase 2 stays inert for three releases.** It is deliberately untestable until Phase 5, so keep the gates trivially simple and obviously correct on inspection.

## Version summary

| Version | Phase | Headline |
|---|---|---|
| v1.6 | 1 | Swipe-by-5 order entry, haptics, shop exclusion from grand total |
| v1.7 | 2 | Hybrid nav + drawer, settings redesign |
| v1.8 | 3 | Counter stock for Cafe Milano |
| v1.9 | 4 | Ledger (per v4 plan) + dashboard tabs + reports |
| v2.0 | 5 | Supabase, auth, three-tier roles |
| v2.1 | 6 | Download page, in-app updates, agent docs, device test harness |
