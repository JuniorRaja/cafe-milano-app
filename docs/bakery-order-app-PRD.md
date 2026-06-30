# Bakery Order Manager — PRD
> Target: Claude Code  
> Platform: Android (Flutter)  
> Storage: Local SQLite (offline-only, no auth, no backend)  
> Timeline: ~3 weeks

---

## 1. Problem Statement

A bakery owner supplies baked goods (buns, puffs, etc.) to 10–15 shops daily. Orders arrive via WhatsApp texts, voice notes, call transcriptions, and photo images of handwritten lists. He manually consolidates all orders onto paper or forwarded messages, shares the kitchen list the previous night, delivers next morning, and collects bills at end of day. This process is error-prone, time-consuming, and hard to trace.

**This app replaces the paper and WhatsApp consolidation loop entirely.**

---

## 2. Users

| User | Role |
|---|---|
| Bakery Owner (sole user) | Enters orders, views kitchen list, generates bills |

No login. No multi-user. No cloud sync. Single device.

---

## 3. Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter (stable channel) |
| Language | Dart |
| Database | `drift` (SQLite ORM) |
| State Management | `riverpod` |
| Sharing | `share_plus` |
| Navigation | `go_router` |
| Target OS | Android (minSdk 21) |

### pubspec.yaml dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.9.0
  riverpod: ^2.5.0
  flutter_riverpod: ^2.5.0
  go_router: ^14.0.0
  share_plus: ^9.0.0
  intl: ^0.19.0
  uuid: ^4.4.0

dev_dependencies:
  drift_dev: ^2.18.0
  build_runner: ^2.4.0
```

---

## 4. Database Schema

```dart
// shops.dart
class Shops extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// products.dart
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// shop_prices.dart — price per product per shop
class ShopPrices extends Table {
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get price => real()();

  @override
  Set<Column> get primaryKey => {shopId, productId};
}

// standing_orders.dart — default qty per shop per product
class StandingOrders extends Table {
  IntColumn get shopId => integer().references(Shops, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get defaultQty => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {shopId, productId};
}

// daily_orders.dart — one record per shop per day
class DailyOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shopId => integer().references(Shops, #id)();
  DateTimeColumn get orderDate => dateTime()();
  BoolColumn get isConfirmed => boolean().withDefault(const Constant(false))();
}

// order_lines.dart — line items for each daily order
class OrderLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(DailyOrders, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get qty => integer()();
}
```

---

## 5. App Structure

```
lib/
├── main.dart
├── app.dart                        # GoRouter setup, Riverpod ProviderScope
├── database/
│   ├── app_database.dart           # Drift DB class with all tables
│   ├── app_database.g.dart         # Generated
│   └── daos/
│       ├── shop_dao.dart
│       ├── product_dao.dart
│       ├── order_dao.dart
│       └── price_dao.dart
├── models/                         # Drift generated + custom view models
├── providers/
│   ├── shop_provider.dart
│   ├── product_provider.dart
│   ├── order_provider.dart
│   └── date_provider.dart          # Selected date state
├── screens/
│   ├── home/
│   │   └── home_screen.dart        # Daily order list + bottom nav
│   ├── order_entry/
│   │   └── order_entry_screen.dart # Enter/edit order for one shop
│   ├── kitchen_list/
│   │   └── kitchen_list_screen.dart
│   ├── billing/
│   │   └── billing_screen.dart
│   └── settings/
│       ├── settings_screen.dart
│       ├── shops/
│       │   ├── shop_list_screen.dart
│       │   └── shop_form_screen.dart
│       ├── products/
│       │   ├── product_list_screen.dart
│       │   └── product_form_screen.dart
│       └── prices/
│           └── price_matrix_screen.dart
└── widgets/
    ├── shop_order_card.dart
    ├── product_qty_row.dart
    └── share_button.dart
```

---

## 6. Screens & Features

### 6.1 Home Screen — Daily Order List

**Route:** `/`

**Purpose:** Central hub. Shows today's orders across all shops.

**UI Layout:**
- Top: Date selector (today default, can swipe/tap to change date)
- Body: List of all active shops as cards
  - Each card shows: Shop name | Order status (Pending / Confirmed)
  - If order exists: shows item count summary (e.g., "3 items · ₹420")
  - If no order yet: shows "Tap to add order" hint
- FAB or top-right: Button to go to Kitchen List
- Bottom nav: Home | Kitchen List | Bills | Settings

**Behavior:**
- On date change → refresh shop order cards for that date
- Standing orders pre-populate when entering a new order for a shop
- Confirmed orders shown with a green indicator

**Acceptance Criteria:**
- [ ] All active shops listed regardless of order status
- [ ] Order summary visible without opening the order
- [ ] Date navigation works forward and backward
- [ ] Confirmed badge shows correctly

---

### 6.2 Order Entry Screen

**Route:** `/order/:shopId?date=YYYY-MM-DD`

**Purpose:** Enter or edit an order for one shop for one day.

**UI Layout:**
- Header: Shop name + date (read-only)
- Product list: Each row shows
  - Product name
  - Quantity stepper (minus / number / plus)
  - Unit price for this shop (read-only, from ShopPrices)
  - Line total (qty × price, auto-calculated)
- Bottom: Order total | "Confirm Order" button
- "Load Standing Order" button — pre-fills with default quantities

**Behavior:**
- On open: if order already exists for this shop+date → load existing lines
- If no order exists: load standing order quantities as default
- Qty = 0 means product not ordered (don't save zero lines)
- Confirm button → marks `DailyOrder.isConfirmed = true`
- Editing a confirmed order is allowed (no lock)
- Only products with `isActive = true` are shown
- Only products with a price configured for this shop are shown (skip unpriced ones or show greyed out)

**Acceptance Criteria:**
- [ ] Standing order quantities auto-loaded on first open
- [ ] Qty stepper cannot go below 0
- [ ] Line totals update in real-time
- [ ] Order total shown at bottom
- [ ] Save persists even without confirming
- [ ] Re-opening loads last saved state

---

### 6.3 Kitchen List Screen

**Route:** `/kitchen?date=YYYY-MM-DD`

**Purpose:** Consolidated production list for the kitchen. Two views.

**UI Layout:**
- Date shown at top (default: today)
- Toggle tabs:
  - **By Item** — grouped by product
  - **By Shop** — grouped by shop
- Floating share button (WhatsApp icon or generic share)

**By Item View:**
```
Buns          ×  240
Veg Puff      ×   80
Egg Puff      ×   60
Chicken Puff  ×   45
...
```

**By Shop View:**
```
Hotel Raj
  Buns        ×  30
  Veg Puff    ×  10

Star Bakery
  Buns        ×  20
  Egg Puff    ×  15
...
```

**Share Text Format (By Item):**
```
🍞 Kitchen List — 01 Jul 2025

ITEM TOTALS
Buns         : 240
Veg Puff     :  80
Egg Puff     :  60

SHOP-WISE
Hotel Raj     : Buns×30, Veg Puff×10
Star Bakery   : Buns×20, Egg Puff×15

Total items: 5 shops | 440 pieces
```

**Acceptance Criteria:**
- [ ] By Item tab shows sum across all confirmed orders
- [ ] By Shop tab shows per-shop breakdown
- [ ] Both views update if orders change
- [ ] Share sends plain text (readable in WhatsApp)
- [ ] Zero-quantity products hidden from both views

---

### 6.4 Billing Screen

**Route:** `/billing?date=YYYY-MM-DD`

**Purpose:** Generate per-shop bill for end-of-day collection.

**UI Layout:**
- Date selector at top
- List of shops with confirmed orders
- Each row: Shop name | Total amount
- Tap a shop → Bill detail view
- "Share All Bills" button — sends all bills as one text block
- Individual "Share Bill" per shop card

**Bill Detail (per shop):**
```
Bill — Hotel Raj
Date: 01 Jul 2025

Buns      × 30  @ ₹5.00  = ₹150.00
Veg Puff  × 10  @ ₹8.00  =  ₹80.00
Egg Puff  ×  5  @ ₹8.00  =  ₹40.00

TOTAL: ₹270.00
```

**Share Text Format (single shop):**
```
🧾 Bill — Hotel Raj
Date: 01 Jul 2025

Buns      × 30  ₹150
Veg Puff  × 10  ₹ 80
Egg Puff  ×  5  ₹ 40

TOTAL: ₹270
```

**Share All Format:**
```
🧾 Bills — 01 Jul 2025

Hotel Raj    : ₹270
Star Bakery  : ₹190
City Snacks  : ₹340
...
GRAND TOTAL  : ₹800
```

**Acceptance Criteria:**
- [ ] Only confirmed orders show in billing
- [ ] Bill total = sum of (qty × shop-specific price) per line
- [ ] Share formats are WhatsApp-friendly plain text
- [ ] Grand total shown on list screen
- [ ] Share individual and share all both work

---

### 6.5 Settings — Shop Management

**Route:** `/settings/shops`

**Purpose:** Add, edit, deactivate shops.

**UI:**
- List of shops with edit icon
- FAB to add new shop
- Swipe or toggle to deactivate (soft delete only)

**Shop Form Fields:**
- Name (required)
- Phone number (optional, used for future WhatsApp deep link)

**Acceptance Criteria:**
- [ ] Shop name required, cannot be blank
- [ ] Deactivated shops don't appear in order entry or kitchen list
- [ ] Cannot delete shop with existing orders (deactivate instead)

---

### 6.6 Settings — Product Management

**Route:** `/settings/products`

**Purpose:** Add, edit, deactivate products.

**UI:**
- List of products with edit icon
- FAB to add new product

**Product Form Fields:**
- Name (required)

**Acceptance Criteria:**
- [ ] Product name required
- [ ] Deactivated products hidden from order entry
- [ ] Cannot delete product with existing orders

---

### 6.7 Settings — Price Matrix

**Route:** `/settings/prices`

**Purpose:** Set per-product price per shop. Core data for billing.

**UI:**
- Dropdown or list to select a shop
- On shop select: show all active products with editable price field
- Save button per row or auto-save on blur
- Unset prices shown as "—" with tap-to-set

**Acceptance Criteria:**
- [ ] Every shop × product combination can have a unique price
- [ ] Price of 0 is allowed (free item)
- [ ] Unpriced items in order entry show ₹0 / greyed out
- [ ] Price changes affect future billing only (no retroactive recalculation)

---

### 6.8 Settings — Standing Orders

**Route:** `/settings/standing-orders`

**Purpose:** Set default daily quantities per shop per product.

**UI:**
- Same UX as Price Matrix
- Select shop → see all products with qty input
- Standing qty used as default when opening order entry

**Acceptance Criteria:**
- [ ] Per shop, per product default qty saved
- [ ] Qty = 0 means no standing order for that product
- [ ] Opening order entry loads standing order quantities

---

## 7. Navigation

```
Bottom Nav:
  [Home]  [Kitchen]  [Bills]  [Settings]

Settings sub-nav (side list or nested):
  → Shops
  → Products
  → Prices
  → Standing Orders
```

---

## 8. UI / Design Guidelines

- **Framework:** Material 3
- **Theme:** Light mode, warm amber/orange primary (`#F57C00`)
- **Typography:** Default Material fonts (no custom fonts needed)
- **Density:** Comfortable (not compact) — touch-friendly targets
- **Colors:**
  - Primary: `#F57C00` (amber 700)
  - Surface: `#FFFBF5` (warm white)
  - Confirmed badge: `#4CAF50` (green)
  - Pending indicator: `#9E9E9E` (grey)
- **Icons:** Material Icons only (no external icon packs)
- **Qty Stepper:** `-` button | number display | `+` button, minimum tap target 48dp
- **No animations** beyond default Material transitions

---

## 9. Non-Goals (explicitly out of scope)

| Feature | Why excluded |
|---|---|
| Shop-facing ordering app | Internal tool only |
| Cloud sync / backup | Too complex for v1 |
| User login / auth | Single user device |
| Push notifications | No backend |
| Delivery tracking | Manual process |
| Payment collected status | Manual collection |
| WhatsApp API integration | Requires business account, out of scope |
| Voice note / image OCR | Too complex for v1 |
| Profit/loss reports | Not requested |
| Multi-day kitchen planning | Single day scope |

---

## 10. P0 / P1 / P2 Requirements

### P0 — Must Ship
- [ ] Shop + product + price setup
- [ ] Standing order config per shop
- [ ] Daily order entry (pre-fill from standing order)
- [ ] Kitchen list by item + by shop
- [ ] Share kitchen list as WhatsApp text
- [ ] Bill generation per shop (qty × price)
- [ ] Share bill per shop + share all bills
- [ ] Date navigation on all screens

### P1 — Ship if time allows
- [ ] Search/filter on shop list (for 15+ shops)
- [ ] Swipe-to-confirm order shortcut on home screen
- [ ] Order summary chip on home card (items + total)
- [ ] Copy to clipboard button alongside share

### P2 — Future / Don't build now
- [ ] Export orders as PDF
- [ ] Weekly/monthly totals per shop
- [ ] WhatsApp deep link (tap to open chat with shop)
- [ ] Local backup to phone storage
- [ ] Undo/redo on order entry

---

## 11. Seed / Test Data

Scaffold the app with seed data so it's immediately testable:

```dart
// Seed shops
['Hotel Raj', 'Star Bakery', 'City Snacks', 'Fresh Corner', 'Daily Needs']

// Seed products
['Plain Bun', 'Butter Bun', 'Veg Puff', 'Egg Puff', 'Chicken Puff', 'Cream Roll']

// Seed prices (use ₹5 bun, ₹8 puff as defaults, vary per shop by ±1)

// Seed standing orders
// Hotel Raj: Plain Bun×30, Veg Puff×10, Egg Puff×5
// Star Bakery: Butter Bun×20, Chicken Puff×8
```

Run seed only if DB is empty on first launch.

---

## 12. Error States & Edge Cases

| Situation | Behavior |
|---|---|
| Shop has no prices configured | Show warning in order entry: "Prices not set — billing will show ₹0" |
| No orders for selected date | Kitchen list shows "No orders for this date" empty state |
| Standing order qty = 0 | Product still shown in order entry, qty starts at 0 |
| Product deactivated mid-day | Existing order lines preserved, product hidden from new entries |
| Tap confirm with all qty = 0 | Show confirmation dialog: "All quantities are 0. Confirm anyway?" |

---

## 13. File Generation Notes for Claude Code

- Run `flutter pub run build_runner build --delete-conflicting-outputs` after creating Drift table files
- All Drift DAOs should use `watchX()` streams for reactive UI via Riverpod's `StreamProvider`
- Use `ConsumerWidget` / `ConsumerStatefulWidget` throughout
- `GoRouter` routes should be defined as constants in a `AppRoutes` class
- Date handling: always use `DateTime(y, m, d)` (no time component) for order dates to avoid timezone issues
- Share text: use monospace-friendly formatting (spaces for alignment, not tabs)

---

## 14. Folder Bootstrapping Command

```bash
flutter create bakery_order_manager --org com.prasannar --platforms android
cd bakery_order_manager
# then apply pubspec.yaml above
```

---

*End of PRD*
