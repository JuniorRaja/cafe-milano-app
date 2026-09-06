# Code Review Report — Milano Orders

**Scope:** `lib/` directory  
**Date:** 2026-09-06  
**Version:** 1.10.0+14 / Schema v6

---

## Executive Summary

Milano Orders is a well-structured Flutter/Riverpod application. The codebase shows
strong architectural intent with clear layering, a mature component library, and
good use of modern Flutter patterns.

**Key Strengths:**
- Clean Riverpod provider patterns with `autoDispose`
- Strong UI component library (20+ reusable widgets)
- Proper database migration strategy with FK enforcement
- Good use of `clock` package for testability

**Key Concerns:**
- 24+ layering violations (screens calling `databaseProvider` directly)
- Money stored as floats instead of integer cents
- Unencrypted backup files containing all business data
- 15+ deprecated constant usages still in codebase

---

## Architecture

### Directory Structure

```
lib/
├── database/          # Drift ORM: tables, DAOs, migrations
│   ├── tables/        # 10 table definitions
│   └── daos/          # 9 DAO files
├── providers/         # 15 Riverpod provider files
├── screens/           # Feature screens grouped by domain
├── widgets/           # Shared widgets
│   ├── ui/            # Design system components (20+)
│   └── shell/         # Navigation shell, drawer, app lifecycle
├── services/          # Backup, PDF generation, update check
├── theme/             # Tokens, brand config, app theme
├── models/            # Data transfer objects
└── utils/             # Money formatting, greeting, clock
```

### Layering

The intended architecture:

```
tables → DAOs → providers → screens/widgets
```

**Finding:** Screens bypass providers and call `databaseProvider` directly in 24+
locations across 12 files. This breaks testability and the separation of concerns.
The AGENTS.md file acknowledges this as a known defect. Doc 14a tracks the fix.

### Navigation

- Uses `go_router` with `ShellRoute` for bottom navigation
- Route constants in `AppRoutes` class
- 5 shell branches: Home, Orders, Kitchen, Finances, Settings

---

## Database Layer

### Schema (v6)

10 tables with proper foreign key constraints and indexes:

| Table | Purpose |
|-------|---------|
| `shops` | Retail shop master data |
| `products` | Product catalog |
| `categories` | Product categories |
| `shop_prices` | Per-shop pricing |
| `standing_orders` | Default order quantities |
| `daily_orders` | Order headers |
| `order_lines` | Order line items |
| `payments` | Payment records |
| `payment_allocations` | FIFO payment allocation |
| `business_info` | Single-row business config |

### DAO Pattern

9 DAOs handle all database access:

- **Good:** Transactions for multi-step operations, parameterized queries
- **Good:** Stream-based `watch*` methods for reactive UI
- **Concern:** `dashboard_dao.dart` (400+ lines) and `ledger_dao.dart` (400+ lines)
  contain complex raw SQL with subqueries

### Money Handling

**Finding:** Money is stored as `RealColumn` (SQLite REAL / double). Comparison uses
epsilon (`_moneyEpsilon = 0.005`). This risks floating-point rounding errors.

```dart
// Current approach
final moneyEpsilon = 0.005;
if ((total - allocated).abs() < moneyEpsilon) { ... }
```

Standard practice: store money as integer cents.

---

## Providers Layer

### Patterns

- 15 provider files with clean Riverpod patterns
- `autoDispose` on all family providers prevents memory leaks
- `StreamProvider` wraps DAO `watch*` methods correctly
- `StateNotifier` for dashboard settings persistence
- Custom `readStreamOnce` extension for one-shot reads

### Clock Package

Uses `package:clock` for date queries. Enables deterministic testing.

```dart
final todayProvider = Provider<DateTime>((ref) {
  final now = clock.now();
  return DateTime(now.year, now.month, now.day);
});
```

### Large Files

`dashboard_provider.dart` is 300+ lines. Could split by feature area.

---

## UI Layer

### Component Library

Strong design system in `lib/widgets/ui/`:

| Widget | Purpose |
|--------|---------|
| `AppScaffold` | Standard screen layout with header |
| `AppCard` | Themed card with consistent styling |
| `AppButton` | Semantic button (primary, secondary, destructive) |
| `AppSearchField` | Standard search input |
| `AppSkeleton` | Loading placeholders |
| `EmptyState` | No-data states with optional CTA |
| `StatusBadge` | Order status chips |
| `FilterChipRow` | Filter UI pattern |
| `confirmDestructive` | Standard destructive action dialog |

### Findings

1. **Deprecated constants:** 15+ usages of `kBrandBrown`, `kBrandGold`, `kSurface`
   remain. These should migrate to `AppColors` tokens.

2. **Large screens:** `order_entry_screen.dart` (500+ lines) and
   `shop_ledger_screen.dart` (500+ lines) could be split into smaller widgets.

3. **Duplicate widgets:** Private `_EmptyState` in `home_shops_screen.dart` and
   `kitchen_screen.dart` when `EmptyState` exists in `ui/`.

4. **Inconsistent patterns:** Some screens use raw `Card` instead of `AppCard`.

5. **Hardcoded currency:** `record_payment_sheet.dart` lines 112, 126, 152 write
   literal `₹` instead of using `money.dart` formatter.

---

## Services

### Backup Service

- Uses `compute()` isolate for JSON serialization — good for performance
- Exports to unencrypted JSON file with all business data
- No database encryption (SQLite file is plaintext)

### PDF Generation

- `catalog_share_service.dart` generates product catalog PDF
- Uses `pdf` package correctly
- Loads images with proper error handling

### Update Service

- Checks GitHub releases API over HTTPS
- Proper error handling with `try/catch`
- Returns `null` on failure (graceful degradation)

---

## Security

### Good Practices

| Area | Status |
|------|--------|
| SQL injection | ✓ Parameterized queries throughout |
| Input validation | ✓ Form validators on required fields |
| HTTPS | ✓ Update check uses HTTPS |
| Hardcoded secrets | ✓ None found |

### Concerns

| Issue | Severity | Notes |
|-------|----------|-------|
| Unencrypted backups | Medium | JSON contains all business data |
| No database encryption | Medium | SQLite file readable on rooted device |
| Absolute photo paths | Low | Stored paths could enable path traversal |
| No authentication | N/A | By design (single-user app per AGENTS.md) |

---

## Performance

### Good Practices

| Area | Implementation |
|------|----------------|
| Image caching | `cacheWidth`/`cacheHeight` on list images |
| Heavy computation | `compute()` isolate for backup JSON |
| Paint boundaries | `RepaintBoundary` on pulse card, background |
| Controller disposal | All 5 `AnimationController` instances disposed |
| Stream management | Riverpod handles subscriptions via `autoDispose` |

### Concerns

| Issue | Location | Impact |
|-------|----------|--------|
| No `cacheWidth` on images | `product_qty_row.dart`, `product_form_screen.dart` | Jank in lists |
| Multiple `ref.watch` in builds | `finances_screen.dart`, `pulse_card.dart` | Cascading rebuilds |
| No `itemExtent` on lists | All `ListView.builder` uses | Minor optimization missed |

---

## Code Quality

### Repeated Patterns

1. **`databaseProvider` direct calls:** 24+ locations bypass provider layer
2. **Loading indicators:** ~25 `CircularProgressIndicator` usages, inconsistent styling
3. **Empty states:** Duplicate private implementations instead of using `EmptyState`
4. **Status badges:** Private `_StatusBadge` when public `StatusBadge` exists

### Test Coverage

- `test/` directory exists with migration, provider, and UI tests
- Uses `SharedPreferences.setMockInitialValues` for settings tests
- Dashboard provider tests verify caching behavior

---

## Summary

The codebase demonstrates solid Flutter/Riverpod fundamentals. The main technical
debt is the layering violations (screens calling database directly) which the team
has already documented in AGENTS.md and tracked for resolution.

Priority fixes:
1. Complete the provider seam refactor (doc 14a)
2. Migrate deprecated color constants to `AppColors`
3. Consider encrypting backup files
4. Store money as integer cents
