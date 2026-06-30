# BakeOrder — Implementation Plan

> Generated: 2026-06-30  
> Last updated: 2026-06-30  
> Status: Phase 7 complete — Phase 8 next  
> Platform: Android (Flutter)  
> Estimated timeline: ~3 weeks  
> **App root: `E:\Works\pr-mob-app\CafeMilano\`**  
> **Package name: `cafe_milano`** (already scaffolded — no `flutter create` needed)

---

## Locked Decisions (deviations from PRD)

### Schema changes

| Table | Change | Reason |
|---|---|---|
| `Shops` | + `area TEXT nullable` | UI mockup shows "Anna Nagar, Chennai" on shop cards and dropdowns |
| `Products` | + `unit TEXT nullable` (e.g. "pc", "kg") | UI mockup shows "₹35 / pc" in order entry |
| `Products` | + `photoPath TEXT nullable` | Owner picks from device gallery; placeholder icon shown if unset |
| `OrderLines` | + `unitPrice REAL` | Price snapshot at save time — prevents retroactive billing changes when prices are updated later |

### Navigation (final)

Bottom nav: **[Home | Orders | Kitchen | Profile]**

| Tab | Route | Content |
|---|---|---|
| Home | `/` | Date selector + shop order cards for that day |
| Orders | `/orders` | Daily orders summary → tap → billing detail per shop |
| Kitchen | `/kitchen` | Kitchen Production: By Item / By Shop toggle |
| Profile | `/profile` | Settings hub: Shops, Products, Prices, Standing Orders |

No FAB on Home screen.

### Behavior decisions

| Decision | Choice |
|---|---|
| "Load Standing Order" on existing order | Show confirm dialog before overwriting |
| Billing: which orders show? | All orders — confirmed + pending |
| Edit a confirmed order | Auto-reverts order to Pending |
| Product photos | Optional, owner picks from gallery; placeholder if unset |
| Order Type field (UI-5) | Static label "Regular Order" — no logic, display only |
| Price in bills | Uses `OrderLines.unitPrice` (snapshot), not current `ShopPrices` |

---

## Final Schema

```dart
// shops.dart
class Shops extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get area => text().nullable()();       // "Anna Nagar, Chennai"
  TextColumn get phone => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// products.dart
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get unit => text().nullable()();        // "pc", "kg", "dozen"
  TextColumn get photoPath => text().nullable()();   // local file path
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// shop_prices.dart
class ShopPrices extends Table {
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get price => real()();

  @override
  Set<Column> get primaryKey => {shopId, productId};
}

// standing_orders.dart
class StandingOrders extends Table {
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get defaultQty => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {shopId, productId};
}

// daily_orders.dart
class DailyOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  DateTimeColumn get orderDate => dateTime()();      // always DateTime(y,m,d) — no time
  BoolColumn get isConfirmed => boolean().withDefault(const Constant(false))();
}

// order_lines.dart
class OrderLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(DailyOrders, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get qty => integer()();
  RealColumn get unitPrice => real()();              // snapshot from ShopPrices at save time
}
```

---

## Phase 1 — Flutter Bootstrap

**Goal:** Runnable shell app with correct theme, routing skeleton, and Drift wired up.

### Action Items

- [x] Apply `pubspec.yaml` with all dependencies to `CafeMilano/pubspec.yaml` (drift, riverpod, go_router, share_plus, intl, uuid, image_picker)
- [x] Add `drift_dev` + `build_runner` to dev_dependencies
- [x] Configure Material 3 theme:
  - Primary `#F57C00` (amber 700)
  - Surface `#FFFBF5` (warm white)
  - Seed color: amber
- [x] Create `lib/app.dart` — GoRouter with all named routes defined as `AppRoutes` constants, bottom nav shell
- [x] Create `lib/main.dart` — `ProviderScope` wrapping `MaterialApp.router`
- [x] Create all screen stub files (return `Scaffold` with title only) for each route
- [x] Verify bottom nav renders and tab switching works

### Success Criteria

- `flutter run` launches without errors
- All 4 bottom nav tabs navigate to their stub screens
- App title "BakeOrder" appears in AppBar
- Amber primary color visible on nav bar active icon

---

## Phase 2 — Database Layer

**Goal:** All tables defined, code-generated, and seed data running on first launch.

### Action Items

- [x] Create `lib/database/tables/` with one file per table (shops, products, shop_prices, standing_orders, daily_orders, order_lines)
- [x] Create `lib/database/app_database.dart` — `@DriftDatabase` class listing all tables
- [x] Run `flutter pub run build_runner build --delete-conflicting-outputs`
- [x] Implement `lib/database/seed_data.dart`:
  - Check if DB is empty (count shops)
  - If empty: insert 5 shops (with area), 6 products (with unit), seed prices (₹5 buns ±1, ₹8 puffs ±1 per shop), seed standing orders per PRD §11
- [x] Register `AppDatabase` as a Riverpod `Provider` (singleton, lazy init)
- [x] Call seed on app startup in `main.dart`

### Success Criteria

- Code generation completes without errors
- App launches and seed data is inserted exactly once (re-launch does not duplicate)
- Can query shops from Drift in a test widget and see 5 results
- DB file is created at the correct path on device (via `path_provider`)

---

## Phase 3 — DAOs + Providers

**Goal:** Full reactive data layer. Every screen will use these streams; no direct DB calls from UI.

### Action Items

**DAOs** (`lib/database/daos/`)

- [ ] `shop_dao.dart`
  - `watchActiveShops()` → `Stream<List<Shop>>`
  - `watchAllShops()` → `Stream<List<Shop>>`
  - `upsertShop(ShopsCompanion)` → `Future<int>`
  - `setShopActive(int id, bool active)`

- [ ] `product_dao.dart`
  - `watchActiveProducts()` → `Stream<List<Product>>`
  - `upsertProduct(ProductsCompanion)` → `Future<int>`
  - `setProductActive(int id, bool active)`

- [ ] `order_dao.dart`
  - `watchShopOrdersForDate(DateTime date)` → stream of all `DailyOrder`s for that date (all shops)
  - `watchOrderWithLines(int orderId)` → stream of order + its lines
  - `upsertOrderWithLines(DailyOrder, List<OrderLine>)` → transaction: upsert order, delete existing lines, insert new lines (skip qty=0)
  - `setConfirmed(int orderId, bool confirmed)`
  - `getOrCreateOrder(int shopId, DateTime date)` → `Future<DailyOrder>`

- [ ] `price_dao.dart`
  - `watchPricesForShop(int shopId)` → `Stream<List<ShopPrice>>`
  - `upsertPrice(ShopPricesCompanion)`
  - `getPrice(int shopId, int productId)` → `Future<ShopPrice?>`
  - `watchStandingOrdersForShop(int shopId)` → `Stream<List<StandingOrder>>`
  - `upsertStandingOrder(StandingOrdersCompanion)`

**Riverpod Providers** (`lib/providers/`)

- [ ] `shop_provider.dart` — `activeShopsProvider` (StreamProvider), `allShopsProvider`
- [ ] `product_provider.dart` — `activeProductsProvider` (StreamProvider)
- [ ] `order_provider.dart` — `ordersForDateProvider(DateTime)` (StreamProvider.family), `orderWithLinesProvider(int)` (StreamProvider.family)
- [ ] `price_provider.dart` — `pricesForShopProvider(int)`, `standingOrdersForShopProvider(int)`
- [ ] `date_provider.dart` — `selectedDateProvider` (StateProvider, default: today)

### Success Criteria

- Modifying seed data via Drift directly reflects in a `StreamProvider` watcher without hot reload
- `upsertOrderWithLines` is atomic — no partial saves
- Zero-qty lines are never persisted
- DAOs compile cleanly with generated code

---

## Phase 4 — Settings / Profile Screens

**Goal:** Owner can manage shops, products, prices, and standing orders before entering any orders.

### Action Items

**Profile Hub** (`/profile`)
- [ ] Settings list screen: 4 tiles → Shops, Products, Prices, Standing Orders

**Shop Management** (`/profile/shops`, `/profile/shops/new`, `/profile/shops/:id/edit`)
- [ ] Shop list: `watchAllShops()` stream, active toggle chip, edit icon
- [ ] Swipe-to-deactivate or toggle; deactivated shown dimmed at bottom
- [ ] Shop form: Name (required, validation), Area (optional), Phone (optional)
- [ ] Block hard-delete if shop has any `DailyOrder` rows — show snackbar "Deactivate instead"

**Product Management** (`/profile/products`, `/profile/products/new`, `/profile/products/:id/edit`)
- [ ] Product list: same pattern as shops
- [ ] Product form: Name (required), Unit (optional text field, e.g. "pc"), Photo (optional — `image_picker`, show thumbnail + "Change / Remove")
- [ ] Block hard-delete if product has any `OrderLine` rows

**Price Matrix** (`/profile/prices`)
- [ ] Shop dropdown (all active shops)
- [ ] On shop select: list all active products with editable price text field
- [ ] Unset prices shown as empty/placeholder "—"
- [ ] "Save Changes" full-width button at bottom — batch upsert all prices

**Standing Orders** (`/profile/standing-orders`)
- [ ] Identical UX to Price Matrix
- [ ] Qty text field (integer) instead of price
- [ ] "Save Changes" button — batch upsert all standing orders

### Success Criteria

- [x] Cannot save a shop/product with blank name (form validates)
- [x] Deactivated shops disappear from Price Matrix and Standing Orders dropdowns; Home and Order Entry verified in Phase 5/6
- [x] Price matrix saves correctly — reload screen shows saved values
- [x] Price of ₹0 is valid and saves without error
- [x] Product photo: picking from gallery stores path; placeholder shows when no photo set
- [ ] Cannot delete shop or product that has existing orders — snackbar shown *(deferred: requires Order Entry data from Phase 6)*

---

## Phase 5 — Home Screen

**Goal:** Owner's daily hub. See all shops and their order status for any date at a glance.

### Action Items

- [x] Date selector row: `<` prev day | `📅 DD Mon YYYY, Day` | `>` next day
  - Tapping the date label opens a date picker (no future date restriction)
  - `selectedDateProvider` drives the date
- [x] "Shops · N shops" section header (count of active shops)
- [x] `ShopOrderCard` widget — reads from `ordersForDateProvider(selectedDate)`:
  - Circular product icon / shop photo placeholder (amber background)
  - Shop name (bold)
  - Area subtitle (grey)
  - Confirmed (green chip) / Pending (grey chip) badge
  - If order exists: "N items · ₹X,XXX" summary chips
  - If no order: "Tap to add order" hint text
- [x] Tap card → navigate to `/order/:shopId?date=YYYY-MM-DD`
- [x] No FAB on this screen

### Success Criteria

- [x] All active shops listed regardless of whether an order exists for the date
- [x] Changing the date refreshes all cards reactively (no manual refresh)
- [x] Confirmed badge renders green; Pending renders grey
- [x] Order summary (items + total) visible on card without opening the order
- [x] Deactivated shops do not appear

---

## Phase 6 — Order Entry Screen

**Goal:** The most complex screen. Enter or edit an order for one shop for one day.

### Action Items

- [x] Route: `/order/:shopId?date=YYYY-MM-DD`
- [x] AppBar: back arrow | shop icon + shop name + area | "Load Standing Order" (orange text button)
- [x] Sub-header: "Order Date: DD Mon YYYY, Day · Regular Order" (static)
- [x] On screen open:
  - Call `getOrCreateOrder(shopId, date)` to get/create the `DailyOrder`
  - If order has existing lines → load those quantities
  - If order is new (no lines yet) → auto-fill from `watchStandingOrdersForShop` (qty = standing default, 0 if not set)
- [x] `ProductQtyRow` widget per active product with price set for this shop:
  - Product photo thumbnail (or placeholder icon)
  - Product name
  - `₹price / unit · ₹lineTotal` (unit from `Products.unit`, lineTotal = qty × price)
  - `−` button | qty display | `+` button (min 0, 48dp tap targets)
- [x] Products with no price for this shop: shown greyed out with "Price not set" and qty stepper disabled
- [x] Bottom bar (sticky): "Order Total · N items" left | "Confirm Order →" button right
- [x] Auto-save: any stepper change triggers a debounced upsert (500ms) — no explicit save button
- [x] "Confirm Order" button:
  - If all qty = 0 → dialog: "All quantities are 0. Confirm anyway?" Yes/No
  - On confirm: set `isConfirmed = true`, snapshot `unitPrice` from `ShopPrices` into each `OrderLine`
- [x] "Load Standing Order" button:
  - If order has any lines → dialog: "Replace current entries with standing order quantities? This cannot be undone." Confirm / Cancel
  - On confirm: overwrite all qtys with standing order defaults
- [x] Any edit after confirmation → set `isConfirmed = false` automatically

### Success Criteria

- [x] Standing order quantities auto-loaded on first open (no existing lines)
- [x] Re-opening a saved order loads last saved state
- [x] Qty stepper cannot go below 0
- [x] Line totals update in real-time as qty changes
- [x] Order total at bottom updates reactively
- [x] Zero-qty lines not saved to DB
- [x] Confirming an order sets `isConfirmed = true`
- [x] Editing after confirm auto-reverts to Pending
- [x] "Load Standing Order" confirm dialog shown; overwrite works correctly
- [x] Unpriced products are greyed out and non-interactive
- [x] Warning visible when any products have no price set: "Prices not set for N products — billing will show ₹0"

---

## Phase 7 — Orders Tab (Daily Summary + Billing)

**Goal:** See the day's billing totals and share bills with shops.

### Action Items

**Orders Tab — Daily Summary** (`/orders`)
- [x] Date selector (same component as Home, but can use its own local date state)
- [x] List of all shops with any order for the selected date
- [x] Each row: shop name + area | total (₹X,XXX) | Confirmed/Pending chip | share icon
- [x] Grand Total sticky footer
- [x] "Share All Bills" button (WhatsApp icon) — generates combined text block
- [x] Tap shop row → expand inline accordion (like UI-3) showing line items

**Billing Detail (inline accordion)**
- [x] Expandable card: Item | Qty | Price | Total columns
- [x] Calculates from `OrderLines.unitPrice` (snapshot) — not current `ShopPrices`
- [x] "Total: ₹X,XXX" row at bottom of expanded card
- [x] Share icon per card → share individual bill text

**Share Text Formats**

Single shop:
```
🧾 Bill — Hotel Raj
Date: 01 Jul 2025

Buns      × 30  ₹150
Veg Puff  × 10  ₹ 80

TOTAL: ₹230
```

All bills:
```
🧾 Bills — 01 Jul 2025

Hotel Raj    : ₹230
Star Bakery  : ₹190

GRAND TOTAL  : ₹420
```

### Success Criteria

- [x] All shops with any order (confirmed or pending) appear in the list
- [x] Bill total = sum of `qty × unitPrice` per `OrderLine` (snapshot, not current price)
- [x] Grand total correct across all shops
- [x] Accordion expand/collapse is smooth and does not reset on scroll
- [x] Individual share and share-all both produce readable plain text
- [x] Empty state shown if no orders exist for selected date

---

## Phase 8 — Kitchen Screen

**Goal:** Consolidated production list for the kitchen; shareable via WhatsApp.

### Action Items

- [ ] Route: `/kitchen`
- [ ] Date selector at top right (tap to open date picker, with `<` `>` arrows)
- [ ] Segmented control: **By Item** | **By Shop**

**By Item tab**
- [ ] Header row: "Item | Quantity (pcs)"
- [ ] Aggregate `SUM(qty)` grouped by product across all orders for the date
- [ ] Product icon (small) + product name + bold quantity
- [ ] Sorted by quantity descending (highest first)
- [ ] Hide products with total qty = 0

**By Shop tab**
- [ ] Group by shop; within each shop, list products with qty
- [ ] Shop name as section header
- [ ] Same zero-qty exclusion

**Share (WhatsApp FAB)**
- [ ] Green WhatsApp icon FAB bottom-right
- [ ] Share text always contains both sections regardless of active tab:

```
🍞 Kitchen List — 01 Jul 2025

ITEM TOTALS
Buns         : 240
Veg Puff     :  80

SHOP-WISE
Hotel Raj     : Buns×30, Veg Puff×10
Star Bakery   : Buns×20, Veg Puff×15

Total: 2 shops | 395 pieces
```

- [ ] Use space-padded alignment (not tabs) for WhatsApp compatibility

### Success Criteria

- [ ] By Item shows correct aggregate totals across all orders for the date
- [ ] By Shop shows correct per-shop breakdown
- [ ] Both views update reactively if an order is edited elsewhere
- [ ] Zero-quantity products hidden from both views
- [ ] Empty state shown if no orders exist for the date: "No orders for this date"
- [ ] Share text is readable in WhatsApp (plain text, no markdown)
- [ ] Switching between tabs does not reset the date

---

## Phase 9 — Polish, Edge Cases & Final QA

**Goal:** Every error state handled; app is production-ready.

### Action Items

**Edge cases from PRD §12**
- [ ] Shop has no prices: warning shown in Order Entry ("Prices not set — billing will show ₹0")
- [ ] No orders for date: Kitchen and Orders tabs show "No orders for this date" empty state with icon
- [ ] Standing order qty = 0: product shown in order entry, qty starts at 0
- [ ] Product deactivated mid-day: existing `OrderLine` rows preserved; product hidden from new order entries
- [ ] Confirm order with all qty = 0: dialog shown before confirming

**UX polish**
- [ ] Pull-to-refresh on all list screens (Drift streams should handle this automatically)
- [ ] Loading states (shimmer or circular indicator) while streams emit first value
- [ ] Snackbar feedback on all write operations (save, confirm, price update, etc.)
- [ ] Back navigation from Order Entry saves automatically (no "unsaved changes" prompt needed — auto-save is in place)
- [ ] Keyboard dismissal on price/qty text fields when tapping outside

**Testing**
- [ ] Walk through seed data end-to-end: enter orders for all 5 seed shops → view kitchen list → view billing → share
- [ ] Change a product price after confirming an order → verify bill still shows original price
- [ ] Deactivate a shop → verify it disappears from Home
- [ ] Delete (deactivate) a product with existing order lines → verify lines preserved in billing

### Success Criteria

- [ ] All P0 requirements from PRD §10 are satisfied
- [ ] No crashes on any screen with empty DB (fresh install, no seed data)
- [ ] Share text renders correctly in WhatsApp (tested manually)
- [ ] App handles date navigation 30 days forward and backward without issues
- [ ] APK builds cleanly: `flutter build apk --release`

---

## Dependency Additions (beyond PRD pubspec)

```yaml
dependencies:
  image_picker: ^1.1.0   # product photos from gallery
```

```xml
<!-- CafeMilano/android/app/src/main/AndroidManifest.xml -->
<!-- Required for image_picker on Android -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```

---

## File Structure (revised)

All paths are relative to `CafeMilano/`. Dart package imports use `package:cafe_milano/...`.

```
lib/
├── main.dart
├── app.dart                              # GoRouter + ProviderScope
├── database/
│   ├── app_database.dart
│   ├── app_database.g.dart               # Generated
│   ├── seed_data.dart
│   └── daos/
│       ├── shop_dao.dart
│       ├── product_dao.dart
│       ├── order_dao.dart
│       └── price_dao.dart
├── providers/
│   ├── shop_provider.dart
│   ├── product_provider.dart
│   ├── order_provider.dart
│   ├── price_provider.dart
│   └── date_provider.dart
├── screens/
│   ├── home/
│   │   └── home_screen.dart
│   ├── orders/
│   │   └── orders_screen.dart            # Daily summary + inline billing
│   ├── order_entry/
│   │   └── order_entry_screen.dart
│   ├── kitchen/
│   │   └── kitchen_screen.dart
│   └── profile/
│       ├── profile_screen.dart           # Settings hub
│       ├── shops/
│       │   ├── shop_list_screen.dart
│       │   └── shop_form_screen.dart
│       ├── products/
│       │   ├── product_list_screen.dart
│       │   └── product_form_screen.dart
│       ├── prices/
│       │   └── price_matrix_screen.dart
│       └── standing_orders/
│           └── standing_orders_screen.dart
└── widgets/
    ├── shop_order_card.dart
    ├── product_qty_row.dart
    ├── date_selector.dart
    └── share_button.dart
```

---

## Route Constants

```dart
class AppRoutes {
  static const home = '/';
  static const orders = '/orders';
  static const kitchen = '/kitchen';
  static const profile = '/profile';
  static const orderEntry = '/order/:shopId';   // ?date=YYYY-MM-DD
  static const shops = '/profile/shops';
  static const shopNew = '/profile/shops/new';
  static const shopEdit = '/profile/shops/:id/edit';
  static const products = '/profile/products';
  static const productNew = '/profile/products/new';
  static const productEdit = '/profile/products/:id/edit';
  static const prices = '/profile/prices';
  static const standingOrders = '/profile/standing-orders';
}
```

---

*All work happens inside `CafeMilano/`.*

---
## Later

- Once everything is done, let's explore HIVE DB to swap it over SQLITE
- Shared Preferrence (Caching)
- BLOC w CLEAN ARCH