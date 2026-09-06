# Areas of Improvement — Milano Orders

**Date:** 2026-09-06  
**Companion doc:** [code-review-report.md](code-review-report.md)

---

## Priority Matrix

| Priority | Area | Effort | Impact |
|----------|------|--------|--------|
| High | Complete provider seam refactor | Medium | High |
| High | Store money as integer cents | Medium | High |
| Medium | Encrypt backup files | Low | Medium |
| Medium | Migrate deprecated constants | Low | Medium |
| Low | Split large files | Medium | Low |
| Low | Add image caching to remaining files | Low | Low |

---

## High Priority

### 1. Complete the Provider Seam Refactor

**Problem:** 24+ screen locations call `ref.read(databaseProvider)` directly. This
violates the layering rule in AGENTS.md and blocks testability.

**Files affected:**
- `order_entry_screen.dart`
- `shop_ledger_screen.dart`
- `record_payment_sheet.dart`
- `backup_restore_screen.dart`
- And 8+ more screens

**Action:** Implement doc 14a (`docs/features/14a-repository-seam.md`). Move all
write operations to providers. Screens should only call provider methods, never
access the database directly.

**Example refactor:**

```dart
// Before (in screen)
final db = ref.read(databaseProvider);
await db.orderDao.confirmOrder(orderId);

// After (in provider)
// providers/order_provider.dart
Future<void> confirmOrder(WidgetRef ref, int orderId) async {
  final db = ref.read(databaseProvider);
  await db.orderDao.confirmOrder(orderId);
}

// In screen
await confirmOrder(ref, orderId);
```

---

### 2. Store Money as Integer Cents

**Problem:** Money values use `RealColumn` (double). Comparisons use epsilon
(`0.005`). This risks floating-point rounding errors on accumulations.

**Files affected:**
- `lib/database/tables/` — all price/amount columns
- `lib/database/daos/ledger_dao.dart` — epsilon comparisons
- `lib/utils/money.dart` — formatting

**Action:**

1. Add migration to convert REAL columns to INTEGER (cents)
2. Update DAOs to divide by 100 when reading
3. Update formatters to accept integers
4. Remove epsilon comparisons

**Example:**

```dart
// Before
RealColumn get price => real()();

// After
IntColumn get priceCents => integer()();

// In DAO
double getPrice(int cents) => cents / 100.0;
```

---

## Medium Priority

### 3. Encrypt Backup Files

**Problem:** Backup exports are unencrypted JSON. Contains all business data:
shops, products, prices, orders, payments.

**Current flow:**
```dart
final jsonString = await compute(_buildBackupJson, {...});
await file.writeAsString(jsonString);
```

**Action:** Add optional encryption before export.

```dart
// Option A: Password-based encryption
import 'package:encrypt/encrypt.dart';

Future<void> exportBackup({String? password}) async {
  final json = await compute(_buildBackupJson, {...});
  if (password != null) {
    final key = Key.fromUtf8(password.padRight(32));
    final iv = IV.fromSecureRandom(16);
    final encrypted = Encrypter(AES(key)).encrypt(json, iv: iv);
    await file.writeAsString('${iv.base64}:${encrypted.base64}');
  } else {
    await file.writeAsString(json);
  }
}
```

---

### 4. Migrate Deprecated Color Constants

**Problem:** 15+ usages of `kBrandBrown`, `kBrandGold`, `kSurface` remain. These
are deprecated in favor of `AppColors` tokens.

**Files affected:**
- Multiple screens still import deprecated constants
- `tool/check_tokens.sh` tracks violations

**Action:**

1. Find all usages: `grep -r "kBrand\|kSurface" lib/`
2. Replace with `AppColors` equivalents
3. Remove deprecated exports from `app.dart`
4. Run `tool/check_tokens.sh` to verify count is zero

**Mapping:**
```dart
kBrandBrown  → AppColors.primary
kBrandGold   → AppColors.accent
kSurface     → AppColors.surface
```

---

## Low Priority

### 5. Split Large Files

**Problem:** Several files exceed 400-500 lines, making navigation difficult.

| File | Lines | Suggested split |
|------|-------|-----------------|
| `order_entry_screen.dart` | 500+ | Extract `_OrderLineList`, `_OrderSummaryFooter` |
| `shop_ledger_screen.dart` | 500+ | Extract `_LedgerEntryTile`, `_FilterSheet` |
| `dashboard_dao.dart` | 400+ | Split by query type (KPI, trends, rankings) |
| `ledger_dao.dart` | 400+ | Split by domain (payments, allocations, statements) |
| `dashboard_provider.dart` | 300+ | Split by feature (pulse, charts, flags) |

**Action:** Extract inner classes/functions to separate files. Use `part` directive
or create new widget files in the same folder.

---

### 6. Add Image Caching to Remaining Files

**Problem:** `Image.file` in `product_qty_row.dart` and `product_form_screen.dart`
lacks `cacheWidth`/`cacheHeight`. Large images decode at full resolution, causing
jank during scrolling.

**Current:**
```dart
Image.file(
  File(product.photoPath!),
  fit: BoxFit.cover,
)
```

**Action:**
```dart
Image.file(
  File(product.photoPath!),
  fit: BoxFit.cover,
  cacheWidth: 120,  // 3x the display size
  cacheHeight: 120,
  filterQuality: FilterQuality.low,
)
```

---

### 7. Consolidate Empty State Widgets

**Problem:** Private `_EmptyState` widgets in `home_shops_screen.dart` and
`kitchen_screen.dart` duplicate the public `EmptyState` in `ui/`.

**Action:** Replace private implementations with the shared widget:

```dart
// Before
class _EmptyState extends StatelessWidget { ... }

// After
EmptyState(
  icon: Icons.store_outlined,
  title: 'No shops yet',
  subtitle: 'Add your first shop to get started',
  actionLabel: 'Add Shop',
  onAction: () => context.push(AppRoutes.shopNew),
)
```

---

### 8. Standardize Loading Indicators

**Problem:** ~25 usages of `CircularProgressIndicator` with inconsistent sizing
and positioning.

**Action:** Create a standard loading widget:

```dart
// lib/widgets/ui/app_loading.dart
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
```

---

### 9. Remove Hardcoded Currency Symbols

**Problem:** `record_payment_sheet.dart` (lines 112, 126, 152) writes literal `₹`
instead of using `money.dart` formatter.

**Action:** Use `formatMoney()` from `lib/utils/money.dart` for all currency
display. The formatter reads the symbol from `BrandConfig`.

```dart
// Before
Text('₹${amount.toStringAsFixed(2)}')

// After
Text(formatMoney(amount))
```

---

## Future Considerations

### Database Encryption

For apps handling sensitive financial data, consider encrypting the SQLite file:

```dart
// Using sqlcipher_flutter_libs
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

NativeDatabase.createInBackground(
  file,
  setup: (db) => db.execute("PRAGMA key = 'encryption_key';"),
);
```

This requires switching to `sqlcipher_flutter_libs` package.

---

### Relative Photo Paths

Currently photo paths are stored as absolute paths:
```
/data/user/0/com.example.milano/app_flutter/photos/product_1.jpg
```

Consider storing relative paths and resolving at runtime. Prevents path traversal
and improves backup portability.

---

## Summary

The codebase is in good shape. The most impactful improvements are:

1. **Provider seam refactor** — already planned in doc 14a
2. **Integer cents for money** — prevents subtle rounding bugs
3. **Backup encryption** — protects business data

The remaining items are polish. They improve consistency and maintainability but
don't block functionality.
