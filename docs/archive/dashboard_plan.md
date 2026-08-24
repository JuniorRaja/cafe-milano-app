# Dashboard — Implementation Plan (3 Phases)

**Version**: v1.5 (Phase 4 of v4 roadmap)
**Depends on**: Phase 2 (Categories) for category-level breakdowns
**Chart library**: `fl_chart: ^0.68.0` (~150–250 KB APK impact, no native deps)

---

## Design Philosophy

Each product category is a **mini business unit** — Puffs have different margins, demand patterns, and customer concentration than Cakes. The dashboard shows the business *through the lens of categories*, not as one undifferentiated "total pieces" blob.

Three principles:
1. **Category-first** — every aggregate is broken down by what you sell, not just lumped together.
2. **Comparative** — raw numbers are meaningless without context. Always show "vs previous period."
3. **Actionable** — surface anomalies (declining category, inactive shop, concentration risk) as attention flags, not just charts.

---

## Navigation Changes

| Before | After |
|--------|-------|
| Home tab (`/`) → Shops list | Home tab (`/`) → Dashboard |
| FAB → snackbar "Tap a shop card" | FAB → Home icon 🏠, navigates to `/home/shops` |
| No `/home/shops` route | New route: `/home/shops` → existing shops list (renamed `HomeShopsScreen`) |

- Dashboard is the first screen on app open.
- The centre-docked FAB becomes a persistent shortcut to the shops/order-entry screen.
- Back from shops list returns to Dashboard.

---

## Date Range Pill

Horizontal scrollable segmented control, pinned below app bar.

| Preset | Resolved Range | Mirror (for comparison) |
|--------|---------------|------------------------|
| Today | Current calendar day | Same weekday last week |
| This Week | Monday → today | Previous Mon → same weekday |
| Last Week | Previous Mon → Sun | The week before that |
| This Month | 1st → today | Same window in previous month |
| Last Month | Full previous calendar month | The month before that |
| Last 90 Days | today − 89 → today | Previous 90 days |
| Custom | User-picked `DateTimeRange` | No comparison shown |

Changing the pill re-triggers every provider. All cards animate together.

---

## Dashboard Sections

### Section 1 — The Pulse

**Purpose**: Open the app, glance, know where you stand. Always shows today — ignores the date pill.

**Layout**: Single card, 2×2 metric grid.

| Metric | Calculation | Display |
|--------|-------------|---------|
| **Today's Revenue** | `SUM(qty × unitPrice)` where `orderDate = today` | `₹12,400` — large, brand-brown |
| **vs Same Day Last Week** | `(today − lastWeekSameDay) / lastWeekSameDay × 100` | `↑ 12%` green or `↓ 8%` red |
| **Shops Served** | Count distinct `shopId` with orders today / total active shops | `8 / 11 shops` |
| **Pending Confirmations** | Count `daily_orders` where `orderDate = today AND isConfirmed = false` | `3 pending` — amber if > 0 |

**Empty state**: All zeros displayed cleanly — `₹0`, `→ 0%`, `0 / 11 shops`, `0 pending`.

---

### Section 2 — Category Scorecards

**Purpose**: See each product line's health at a glance. The most important section.

**Layout**: Horizontal `ListView` of cards, each ~160w × 200h. One card per active category (in `sortOrder`) + a final "🍽️ Others" card for uncategorised products.

Each card:
| Element | Data |
|---------|------|
| **Emoji + Name** | From `category_emoji.dart` lookup |
| **Revenue** | `SUM(qty × unitPrice)` for this category in selected range |
| **Volume + Reach** | `{totalPcs} pcs · {shopCount} shops` |
| **7-Day Sparkline** | Daily piece totals for last 7 days (always 7, independent of pill) |
| **Star Product** | Highest-revenue product in this category + its % share |

**Sparkline rendering**: Custom `CustomPainter` — 7 data points. No `fl_chart` needed.

---

### Section 3 — Revenue Anatomy

**Purpose**: Understand revenue *composition* — which categories grow, which shops concentrate risk, which products lead.

#### 3a. Category Revenue Mix
Donut chart (`fl_chart PieChart`) + ranked table. Columns: rank, emoji + name, revenue, share %, trend vs mirror period.

#### 3b. Shop Concentration
Top 5 shops by revenue. Columns: rank, name + area, revenue, % of total, category breadth (emojis of categories ordered + count).

#### 3c. Product Leaderboard
Top 10 products by revenue. Columns: rank, name, category emoji, revenue, qty, shop count.

---

### Section 4 — Operational Patterns

#### 4a. Day-of-Week Heatmap
Grid: rows = categories, columns = Mon–Sun. Cell intensity = average daily pieces for that weekday (last 4 weeks). Answers "which days need more of which category?"

#### 4b. Revenue Trend — Stacked Area Chart
`fl_chart` stacked area. X = last 30 days. Each layer = a category's daily revenue. Shows total trajectory AND composition shifts.

---

### Section 5 — Attention Flags

Computed insights shown as dismissible cards between The Pulse and Category Scorecards — only when relevant.

| Flag | Trigger |
|------|---------|
| **📉 Declining Category** | Revenue down > 15% vs mirror period |
| **🏪 Inactive Shop** | Active shop with 0 orders in last 7 days |
| **⭐ New High** | Category/total hits all-time weekly/monthly high |
| **⚖️ Concentration Risk** | Single shop > 25% of total revenue |
| **⚠️ Zero Day** | Category with daily orders has 0 today |

Max 3 visible; "See all" expands. Dismiss per session. Recompute on range change or app reopen.

---

## Dashboard Settings (Profile → Dashboard)

**Location**: Profile tab → Dashboard Settings tile.

**Layout**:
```
┌──────────────────────────────────────────┐
│  Dashboard Settings                       │
├──────────────────────────────────────────┤
│  Sections                                │
│  ☑ The Pulse (Today's snapshot)     ⓘ   │
│  ☑ Category Scorecards              ⓘ   │
│  ☑ Revenue Anatomy                  ⓘ   │
│  ☑ Operational Patterns             ⓘ   │
│  ☑ Attention Flags                  ⓘ   │
│                                          │
│  Sub-sections                            │
│  ☑ Category Revenue Mix (Donut)     ⓘ   │
│  ☑ Shop Concentration               ⓘ   │
│  ☑ Product Leaderboard              ⓘ   │
│  ☑ Day-of-Week Heatmap              ⓘ   │
│  ☑ Revenue Trend (Stacked)          ⓘ   │
│                                          │
│  📖 KPI Help Guide                       │
└──────────────────────────────────────────┘
```

**Behaviour**:
- Disabling a section hides it from dashboard.
- Sub-sections independently toggleable.
- Disabling "Revenue Anatomy" hides all three sub-cards together.
- At least one section must remain enabled.

**Persistence**: `SharedPreferences`, `Map<String, bool>` by section ID.

```dart
const kDashPulse = 'dash_pulse';
const kDashCategoryCards = 'dash_category_cards';
const kDashRevenueAnatomy = 'dash_revenue_anatomy';
const kDashOperationalPatterns = 'dash_operational_patterns';
const kDashAttentionFlags = 'dash_attention_flags';
const kDashCategoryMix = 'dash_sub_category_mix';
const kDashShopConcentration = 'dash_sub_shop_concentration';
const kDashProductLeaderboard = 'dash_sub_product_leaderboard';
const kDashHeatmap = 'dash_sub_heatmap';
const kDashRevenueTrend = 'dash_sub_revenue_trend';
```

---

## KPI Help Guide

Accessible from Dashboard Settings ("📖 KPI Help Guide" tile) AND from each section's ⓘ icon (navigates to help screen scrolled to that section).

Format: Scrollable screen with expandable tiles. Short, plain-language, no jargon.

| KPI | Help Text |
|-----|-----------|
| **Today's Revenue** | Total sales value from all orders placed today. Calculated as quantity × price for every item across all shops. |
| **vs Same Day Last Week** | Compares today's revenue to the same weekday last week. Green arrow = doing better; red = lower. Helps spot if today is unusually slow or strong. |
| **Shops Served** | How many of your active shops placed at least one order today, out of the total. Low number early in the day is normal — check again by afternoon. |
| **Pending Confirmations** | Orders entered today that haven't been confirmed yet. Zero means all orders are locked in for production. |
| **Category Revenue** | Total sales for one product category in the selected time period. Shows which product lines bring in the most money. |
| **Volume & Reach** | Pieces produced and number of shops ordering from this category. High reach = universal staple; low reach = niche. |
| **7-Day Sparkline** | Tiny chart showing daily production for the last 7 days. Flat = steady demand. Spikes = weekend surge or event orders. |
| **Star Product** | Highest-earning product within a category. The % shows how much the category depends on one item. High % = risk if that product dips. |
| **Category Revenue Mix** | Pie chart showing what fraction of total revenue comes from each category. Spot over-dependence on one product line. |
| **vs Previous Period** | Compares current period revenue to equivalent previous period. Shows which categories are growing or shrinking. |
| **Shop Concentration** | Ranks top shops by spend. If one shop is > 25% of revenue, that's a risk — losing them would hurt significantly. |
| **Category Breadth** | How many categories a shop orders from. Few categories = upsell opportunity. |
| **Product Leaderboard** | Top 10 products by revenue. A top product ordered by only 1–2 shops = dependency risk. |
| **Day-of-Week Heatmap** | Average demand per category per weekday (last 4 weeks). Plan production — more cakes on Fridays, steady buns daily. |
| **Revenue Trend (Stacked)** | 30-day chart with coloured layers per category. If a layer thins, that category is declining even if total looks fine. |
| **Declining Category Flag** | Appears when a category drops > 15% vs previous cycle. Could mean supply issues, seasonal drop, or lost customer. |
| **Inactive Shop Flag** | A regularly-ordering shop hasn't ordered in 7+ days. Worth a phone call. |
| **Concentration Risk Flag** | One shop > 25% of total revenue. Not necessarily bad, but diversification protects you. |

---

## Provider Architecture

```
dashboardSettingsProvider (SharedPreferences-backed)
  → DashboardSettings { showPulse, showCategoryCards, ... }

dashboardRangeProvider (StateProvider<DashboardRange>)
  → { preset, range: DateTimeRange, mirrorRange: DateTimeRange? }
      │
      ├── PULSE
      │   ├─ todayRevenueProvider
      │   ├─ revenueDeltaProvider
      │   ├─ shopsServedTodayProvider
      │   └─ pendingConfirmationsProvider
      │
      ├── CATEGORY SCORECARDS
      │   └─ categoryScorecardsProvider(range)
      │        → List<CategoryScorecard>
      │
      ├── REVENUE ANATOMY
      │   ├─ categoryMixProvider(range)
      │   ├─ shopConcentrationProvider(range)
      │   └─ productLeaderboardProvider(range)
      │
      ├── OPERATIONAL PATTERNS
      │   ├─ weekdayHeatmapProvider
      │   └─ stackedRevenueTrendProvider
      │
      └── ATTENTION FLAGS
          └─ attentionFlagsProvider(range)

All backed by → DashboardDao (grouped SQL aggregations)
```

---

## SQL Reference

### Pulse
```sql
-- Today's revenue
SELECT COALESCE(SUM(ol.qty * ol.unitPrice), 0)
FROM order_lines ol JOIN daily_orders o ON ol.orderId = o.id
WHERE o.orderDate = :today;

-- Shops served
SELECT COUNT(DISTINCT o.shopId) FROM daily_orders o WHERE o.orderDate = :today;

-- Pending
SELECT COUNT(*) FROM daily_orders o WHERE o.orderDate = :today AND o.isConfirmed = 0;
```

### Category Scorecards
```sql
-- Revenue + volume + reach per category
SELECT p.categoryId, COALESCE(SUM(ol.qty * ol.unitPrice), 0) as revenue,
       SUM(ol.qty) as pieces, COUNT(DISTINCT o.shopId) as shops
FROM order_lines ol JOIN daily_orders o ON ol.orderId = o.id
JOIN products p ON ol.productId = p.id
WHERE o.orderDate BETWEEN :start AND :end
GROUP BY p.categoryId;

-- Sparkline (all categories in one query)
SELECT p.categoryId, o.orderDate, SUM(ol.qty) as pieces
FROM order_lines ol JOIN daily_orders o ON ol.orderId = o.id
JOIN products p ON ol.productId = p.id
WHERE o.orderDate >= :today_minus_6
GROUP BY p.categoryId, o.orderDate ORDER BY o.orderDate;

-- Star product per category
SELECT p.categoryId, p.name, SUM(ol.qty * ol.unitPrice) as rev
FROM order_lines ol JOIN daily_orders o ON ol.orderId = o.id
JOIN products p ON ol.productId = p.id
WHERE o.orderDate BETWEEN :start AND :end
GROUP BY p.categoryId, ol.productId ORDER BY rev DESC;
-- (pick top-1 per category in Dart)
```

### Revenue Anatomy
```sql
-- Shop concentration
SELECT s.name, s.area, SUM(ol.qty * ol.unitPrice) as rev,
       COUNT(DISTINCT p.categoryId) as catCount
FROM order_lines ol JOIN daily_orders o ON ol.orderId = o.id
JOIN shops s ON o.shopId = s.id JOIN products p ON ol.productId = p.id
WHERE o.orderDate BETWEEN :start AND :end
GROUP BY o.shopId ORDER BY rev DESC LIMIT 5;

-- Product leaderboard
SELECT p.name, p.categoryId, SUM(ol.qty * ol.unitPrice) as rev,
       SUM(ol.qty) as qty, COUNT(DISTINCT o.shopId) as shops
FROM order_lines ol JOIN daily_orders o ON ol.orderId = o.id
JOIN products p ON ol.productId = p.id
WHERE o.orderDate BETWEEN :start AND :end
GROUP BY ol.productId ORDER BY rev DESC LIMIT 10;
```

### Operational Patterns
```sql
-- Weekday heatmap (last 4 weeks)
SELECT p.categoryId, CAST(strftime('%w', o.orderDate) AS INTEGER) as weekday,
       AVG(daily_total) as avg_pieces
FROM (
  SELECT o.orderDate, p.categoryId, SUM(ol.qty) as daily_total
  FROM order_lines ol JOIN daily_orders o ON ol.orderId = o.id
  JOIN products p ON ol.productId = p.id
  WHERE o.orderDate >= :four_weeks_ago
  GROUP BY o.orderDate, p.categoryId
) sub GROUP BY categoryId, weekday;

-- Stacked revenue trend (30 days)
SELECT o.orderDate, p.categoryId, SUM(ol.qty * ol.unitPrice) as revenue
FROM order_lines ol JOIN daily_orders o ON ol.orderId = o.id
JOIN products p ON ol.productId = p.id
WHERE o.orderDate >= :thirty_days_ago
GROUP BY o.orderDate, p.categoryId ORDER BY o.orderDate;
```

### Attention Flags
```sql
-- Inactive shops (no orders in 7 days)
SELECT s.id FROM shops s WHERE s.isActive = 1
AND s.id NOT IN (SELECT DISTINCT o.shopId FROM daily_orders o WHERE o.orderDate >= :seven_days_ago);
```
Flag logic (declining, concentration, new high, zero day) composed in provider using results from other queries — not separate DAO methods.

---

## File Structure

| File | Purpose |
|------|---------|
| `lib/database/daos/dashboard_dao.dart` | SQL aggregations |
| `lib/providers/dashboard_provider.dart` | Range state + all data providers |
| `lib/providers/dashboard_settings_provider.dart` | SharedPreferences toggle state |
| `lib/models/dashboard_models.dart` | Data classes: `DashboardRange`, `CategoryScorecard`, `AttentionFlag`, etc. |
| `lib/screens/dashboard/dashboard_screen.dart` | Main scrollable shell |
| `lib/screens/dashboard/kpi_help_screen.dart` | Expandable help tiles |
| `lib/screens/profile/dashboard_settings_screen.dart` | Section toggles + help access |
| `lib/widgets/dashboard/date_range_pill.dart` | Segmented date selector |
| `lib/widgets/dashboard/pulse_card.dart` | Section 1 |
| `lib/widgets/dashboard/category_scorecards.dart` | Section 2 (horizontal scroll) |
| `lib/widgets/dashboard/category_sparkline.dart` | CustomPainter for sparklines |
| `lib/widgets/dashboard/revenue_mix_card.dart` | Section 3a (donut + table) |
| `lib/widgets/dashboard/shop_concentration_card.dart` | Section 3b |
| `lib/widgets/dashboard/product_leaderboard_card.dart` | Section 3c |
| `lib/widgets/dashboard/weekday_heatmap.dart` | Section 4a |
| `lib/widgets/dashboard/stacked_revenue_chart.dart` | Section 4b |
| `lib/widgets/dashboard/attention_flags.dart` | Section 5 |
| `lib/screens/home/home_shops_screen.dart` | Renamed from current `home_screen.dart` |

---
---

## Implementation Phases

---

## Phase A — Skeleton & Infrastructure

**Goal**: All files exist, navigation works, settings screen functional, help page complete. Dashboard shows placeholder cards for each section. App compiles and runs. No real data yet.

**Action items:**

- [ ] `pubspec.yaml` — add `fl_chart: ^0.68.0`.
- [ ] Rename `lib/screens/home/home_screen.dart` → `lib/screens/home/home_shops_screen.dart`. Rename class `HomeScreen` → `HomeShopsScreen`. Update all imports.
- [ ] `lib/screens/dashboard/dashboard_screen.dart` — new file. `SingleChildScrollView` → `Column`. For each section, render a placeholder card (`Container` with section title, dashed border, "Coming soon" text). Watches `dashboardSettingsProvider` to conditionally include each placeholder.
- [ ] `lib/app.dart`:
  - Swap Home branch route from `HomeShopsScreen` to `DashboardScreen`.
  - Add `/home/shops` sub-route pointing to `HomeShopsScreen`.
  - Change centre-docked FAB: icon → `Icons.home_rounded`, onPressed → `context.go('/home/shops')`.
  - Add route `/profile/dashboard-settings`.
- [ ] `lib/models/dashboard_models.dart` — new file. Define all data classes:
  - `enum DashboardPreset { today, thisWeek, lastWeek, thisMonth, lastMonth, last90, custom }`
  - `class DashboardRange { final DashboardPreset preset; final DateTimeRange range; final DateTimeRange? mirrorRange; }`
  - `class CategoryScorecard { ... }`
  - `class AttentionFlag { ... }`
  - `class ShopConcentrationRow { ... }`
  - `class ProductLeaderRow { ... }`
  - `class CategoryMixRow { ... }`
- [ ] `lib/providers/dashboard_settings_provider.dart` — new. SharedPreferences-backed. Exposes `DashboardSettings` with all toggle booleans. Default: all enabled.
- [ ] `lib/providers/dashboard_provider.dart` — new. `dashboardRangeProvider` (`StateNotifierProvider`). Data providers as stubs returning empty lists/zeros for now (will be wired in Phase B).
- [ ] `lib/database/daos/dashboard_dao.dart` — new. Stub class with method signatures only (all return empty/zero). Register in `app_database.dart`.
- [ ] `lib/screens/profile/dashboard_settings_screen.dart` — new. Fully functional: toggle switches for each section/sub-section + ⓘ icons that navigate to help. Persists to SharedPreferences immediately on toggle.
- [ ] `lib/screens/dashboard/kpi_help_screen.dart` — new. Fully functional: all 18 KPI help entries as expandable tiles. Accepts optional `scrollToSection` parameter for deep-linking from ⓘ icons.
- [ ] `lib/screens/profile/profile_screen.dart` — add "Dashboard" settings tile (icon: `Icons.dashboard_customize_outlined`) between Categories and Backup.
- [ ] `lib/widgets/dashboard/date_range_pill.dart` — new. Fully functional: renders all presets, handles selection, computes resolved range + mirror range, fires `dashboardRangeProvider` updates. "Custom" opens `showDateRangePicker`.
- [ ] Create empty widget files with minimal `StatelessWidget` stubs (build returns `SizedBox.shrink()`):
  - `lib/widgets/dashboard/pulse_card.dart`
  - `lib/widgets/dashboard/category_scorecards.dart`
  - `lib/widgets/dashboard/category_sparkline.dart`
  - `lib/widgets/dashboard/revenue_mix_card.dart`
  - `lib/widgets/dashboard/shop_concentration_card.dart`
  - `lib/widgets/dashboard/product_leaderboard_card.dart`
  - `lib/widgets/dashboard/weekday_heatmap.dart`
  - `lib/widgets/dashboard/stacked_revenue_chart.dart`
  - `lib/widgets/dashboard/attention_flags.dart`

**Tasks:**

1. Add dependency, rename HomeScreen, wire new routes.
2. Create all model/data classes.
3. Create settings provider + dashboard range provider (stubs).
4. Create stub DashboardDao, register in database.
5. Build Dashboard Settings screen (fully working toggles).
6. Build KPI Help screen (fully working, all entries).
7. Build date range pill (fully working).
8. Build DashboardScreen shell with placeholder cards.
9. Create all widget stub files.
10. Wire Profile → Dashboard Settings tile.
11. Verify app compiles, navigation works end-to-end, toggles hide/show placeholders.

**Success criteria:**

- [ ] App compiles and runs without errors.
- [ ] Home tab shows Dashboard with placeholder cards for each section.
- [ ] FAB shows Home icon; tap navigates to shops list; back returns to Dashboard.
- [ ] Date range pill renders all presets; "Custom" opens date picker; selection state persists in provider.
- [ ] Profile → Dashboard Settings: all toggles work, persist across app restart, hide/show corresponding placeholder cards on Dashboard.
- [ ] KPI Help screen shows all 18 entries; ⓘ icons from Settings navigate to correct entry.
- [ ] Disabling all sections except one prevents the last toggle from being turned off.

---

## Phase B — Core Components (Pulse + Category Scorecards + Revenue Anatomy)

**Goal**: The three most-used sections are fully functional with live data. DashboardDao wired with real SQL. This is the "useful dashboard" milestone — the user gets real value from these alone.

**Action items:**

- [ ] `lib/database/daos/dashboard_dao.dart` — implement:
  - `getRevenueForDate(DateTime date)` → Pulse revenue + delta.
  - `getShopsServedForDate(DateTime date)` → Pulse shops served.
  - `getPendingCountForDate(DateTime date)` → Pulse pending.
  - `getCategoryScores(DateTime start, DateTime end)` → revenue, pieces, shopCount per category.
  - `getCategorySparklines(DateTime sevenDaysAgo)` → all categories' 7-day daily totals in one query.
  - `getStarProducts(DateTime start, DateTime end)` → top product per category (single query, pick top-1 per group in Dart).
  - `getCategoryMix(DateTime start, DateTime end)` → same as category scores + used for donut.
  - `getShopConcentration(DateTime start, DateTime end, {int limit = 5})` → top shops with breadth.
  - `getProductLeaderboard(DateTime start, DateTime end, {int limit = 10})` → top products.
- [ ] `lib/providers/dashboard_provider.dart` — replace stubs with real implementations:
  - `todayRevenueProvider`, `revenueDeltaProvider`, `shopsServedTodayProvider`, `pendingConfirmationsProvider`.
  - `categoryScorecardsProvider(range)`.
  - `categoryMixProvider(range)`, `shopConcentrationProvider(range)`, `productLeaderboardProvider(range)`.
- [ ] `lib/widgets/dashboard/pulse_card.dart` — build full UI: 2×2 grid, hero revenue number, delta arrow, shops served fraction, pending count with amber highlight.
- [ ] `lib/widgets/dashboard/category_scorecards.dart` — horizontal `ListView.builder`. Each card: emoji + name, revenue, volume + reach subtitle, sparkline, star product.
- [ ] `lib/widgets/dashboard/category_sparkline.dart` — `CustomPainter` implementation: 7 data points, smooth curve or line segments, brand-gold stroke.
- [ ] `lib/widgets/dashboard/revenue_mix_card.dart` — `fl_chart PieChart` donut with center total + ranked table below with trend arrows.
- [ ] `lib/widgets/dashboard/shop_concentration_card.dart` — ranked table: shop name, revenue, % share, category emoji badges.
- [ ] `lib/widgets/dashboard/product_leaderboard_card.dart` — ranked table: product, category badge, revenue, qty, shop count.
- [ ] `lib/screens/dashboard/dashboard_screen.dart` — replace placeholder cards for sections 1–3 with real widgets. Keep sections 4–5 as placeholders.
- [ ] Handle empty states for all three sections: zero-data placeholders, no crashes.

**Tasks:**

1. Implement DashboardDao query methods (Pulse + Scorecards + Revenue Anatomy).
2. Wire providers with real DAO calls.
3. Build Pulse card widget.
4. Build Category Scorecards widget + sparkline painter.
5. Build Revenue Mix card (donut + table).
6. Build Shop Concentration card.
7. Build Product Leaderboard card.
8. Integrate into DashboardScreen (replace placeholders).
9. Test empty states (fresh install, no orders).
10. Manual QA with real data at each date range preset.

**Success criteria:**

- [ ] Pulse card shows accurate today's revenue, correct delta vs same day last week, accurate shop count, correct pending count.
- [ ] Category Scorecards display one card per active category + Others; revenue/volume/reach numbers match raw data; sparklines render 7 days correctly.
- [ ] Star Product on each card is genuinely the highest-revenue item for that category in the selected range.
- [ ] Revenue Mix donut slices sum to 100%; trend arrows correctly reflect period-over-period changes.
- [ ] Shop Concentration shows correct top-5 ranking; breadth count matches actual categories ordered.
- [ ] Product Leaderboard shows correct top-10 ranking; shop counts are accurate.
- [ ] Changing date range pill updates all three sections reactively — no stale values.
- [ ] Zero-order state shows clean placeholders: `₹0`, empty scorecards with flat sparklines, "No data" in tables.

---

## Phase C — Advanced Components (Operational Patterns + Attention Flags)

**Goal**: Complete the dashboard. Heatmap, stacked trend chart, and smart alerts all functional. Full polish pass.

**Action items:**

- [ ] `lib/database/daos/dashboard_dao.dart` — implement remaining methods:
  - `getWeekdayHeatmap(DateTime fourWeeksAgo)` → category × weekday average pieces.
  - `getStackedTrend(DateTime thirtyDaysAgo)` → daily revenue per category for 30 days.
  - `getInactiveShopIds(DateTime sevenDaysAgo)` → shops with no orders.
  - `getCategoryRevenuesForRange(start, end)` + `getCategoryRevenuesForRange(mirrorStart, mirrorEnd)` → for decline detection.
- [ ] `lib/providers/dashboard_provider.dart` — implement remaining providers:
  - `weekdayHeatmapProvider`.
  - `stackedRevenueTrendProvider`.
  - `attentionFlagsProvider(range)` — composes flag logic:
    - Declining: compare category revenues current vs mirror, flag if > 15% drop.
    - Inactive: cross-reference active shops vs shops with recent orders.
    - Concentration: check if any shop > 25% of total.
    - Zero Day: check categories with consistent recent history but 0 today.
    - New High: compare current period category total to all-time max for same period length.
- [ ] `lib/widgets/dashboard/weekday_heatmap.dart` — grid widget: row per category (emoji + name), 7 columns (Mon–Sun), coloured cells with opacity proportional to demand intensity. Legend or tooltip showing actual number on tap.
- [ ] `lib/widgets/dashboard/stacked_revenue_chart.dart` — `fl_chart LineChart` configured as stacked area. One layer per category with consistent colour palette. X-axis: dates. Y-axis: revenue. Touch tooltip showing breakdown for that day.
- [ ] `lib/widgets/dashboard/attention_flags.dart` — `Column` of dismissible cards. Each: icon, message, × dismiss button. Max 3 shown; "See all (N)" link if more. Dismissal stored in ephemeral session state (not persisted).
- [ ] `lib/screens/dashboard/dashboard_screen.dart` — replace remaining placeholders with real widgets.
- [ ] Performance pass:
  - Ensure sparklines + heatmap queries are batched (1 query returns all categories).
  - Stacked trend is 1 query, split in Dart.
  - Flags evaluated lazily only when section is enabled + visible.
  - Verify dashboard loads < 2 seconds with 90 days of data on mid-range device.
- [ ] Empty state pass: verify every widget handles zero data gracefully.

**Tasks:**

1. Implement remaining DashboardDao methods (heatmap + trend + flag support).
2. Implement flag computation logic in provider.
3. Build Weekday Heatmap widget.
4. Build Stacked Revenue Chart widget.
5. Build Attention Flags widget (dismissible, prioritised, capped at 3).
6. Integrate into DashboardScreen (replace final placeholders).
7. Performance optimisation: batch queries, lazy flag evaluation.
8. Full empty-state pass across all widgets.
9. Manual QA: all 5 sections with real data, all date presets, toggle combinations.
10. Load test: 90 days, 11 shops, 30 products — verify < 2 second load time.

**Success criteria:**

- [ ] Heatmap correctly shows 4-week averages; demand patterns visually match known business rhythms (e.g., weekend spikes for cakes).
- [ ] Stacked area chart layers sum to correct daily totals; touching a day shows accurate per-category breakdown.
- [ ] Attention Flags: declining category flag fires correctly when revenue drops > 15%; inactive shop flag shows after 7 days of no orders; concentration risk at > 25%.
- [ ] Flags dismiss on tap; max 3 shown; "See all" works when more exist.
- [ ] All 5 sections render correctly together in a single scroll — no layout overflow, no jank.
- [ ] Dashboard Settings toggles work for Sections 4 and 5 (hide heatmap independently of trend, etc.).
- [ ] Dashboard loads < 2 seconds with 90 days of realistic data on mid-range device.
- [ ] Zero-order range shows friendly placeholders everywhere — no error states, no blank sections.
- [ ] Complete dashboard with all sections enabled scrolls smoothly at 60 fps.

---

## Deferred to Phase 6 (v1.7)

- **Outstanding Receivables card** — requires Ledger tables from Phase 5.
- Added as a new toggleable section in Dashboard Settings.
- Tap → "Shops with Outstanding" list screen.

---

## Performance Notes

- All DAO queries use indexed columns (`orderDate`, `shopId`, `productId`, `categoryId`).
- Sparklines (7 points × N categories) batched into one query, split in Dart — no N+1.
- Stacked trend (30 days × N categories) also one grouped query.
- Attention flags computed lazily — only when enabled and visible.
- `fl_chart` renders GPU-accelerated; donut and stacked area are the only heavy widgets.
- SharedPreferences reads cached in provider — no disk I/O per frame.
