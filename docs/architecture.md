# Architecture

Facts. [`AGENTS.md`](../AGENTS.md) has the rules. Update this file with the code.

> `1.9.2+13` · schema v6 · 2026-08-28

## Stack

| | |
|---|---|
| Flutter | `3.44.2`, pinned in CI |
| Dart | `^3.12.2` |
| Database | Drift over SQLite |
| State | Riverpod 2.x |
| Routing | go_router 14.x, `StatefulShellRoute` |
| Charts | `fl_chart` |
| Documents | `pdf` + `printing` |
| Platform | Android. iOS and desktop folders are unmaintained |

Ships as one signed universal APK on GitHub Releases. `update_service.dart` checks for
new ones. No Play Store.

## Directory map

```
lib/
  main.dart          bootstrap: container, seed, runApp
  app.dart           AppRoutes, _router, shell scaffold
  database/
    app_database.dart  @DriftDatabase, schemaVersion, migrations, indexes
    app_database.g.dart  generated — do not edit
    tables/  daos/  seed_data.dart  dev_seed.dart
  models/            dashboard_models.dart
  providers/         ~35 providers
  repositories/      does not exist yet — doc 14a
  screens/           dashboard home kitchen ledger order_entry orders profile splash
  services/          backup catalog_share category_emoji ledger_statement pdf_brand update
  theme/             tokens.dart brand_config.dart app_theme.dart
  utils/money.dart   the one currency formatter
  widgets/ui/        the component kit, 14 components, CI-gated
  widgets/           dashboard cards + older pre-kit widgets
tool/                check_tokens.sh, blur_background.py
test/                10 files
```

## Data model — schema v6, frozen

| Table | Holds |
|---|---|
| `categories` | Product groups |
| `products` | Name, category, optional default price |
| `shops` | Customer shops, each with an opening balance |
| `shop_prices` | One price for one product at one shop |
| `standing_orders` | Default quantity per product, per shop |
| `daily_orders` | One row per shop per date. Carries the confirmed flag |
| `order_lines` | Quantity and unit price per product |
| `payments` | Money received from a shop |
| `payment_allocations` | Which payment paid which order, FIFO |
| `business_info` | Business name, address, logo path |

DAOs: `CategoryDao` `ShopDao` `ProductDao` `OrderDao` `PriceDao` `BusinessInfoDao`
`BackupDao` `DashboardDao` `LedgerDao`.

Foreign keys are enforced. Indexes come from `_createIndexes()` and
`_createLedgerIndexes()`.

**No v7, no v8.** Counter stock and shop exclusion were both dropped. The chain runs v1
to v6 and stops.

If a schema change ever becomes necessary:

1. Increase `schemaVersion`. Add the `onUpgrade` branch.
2. Extend `backup_service.dart` in the same commit. It must round-trip every column and
   fail loudly on an old backup.
3. Run the full chain against a real v4 install.
4. Update this file.

## Design system

All values come from `lib/theme/tokens.dart`.

| Container | Holds |
|---|---|
| `AppColors` | Brand, surface, text, semantic |
| `AppType` | 8 steps, wired into `ThemeData.textTheme` |
| `AppSpace` | `s1`–`s6` = 4, 8, 12, 16, 24, 32. Plus `page` |
| `AppRadius` | Corner scale |
| `AppShadow` | Elevation |

- No color, font size, radius, or shadow literal in `lib/screens/` or `lib/widgets/`.
- `lib/widgets/ui/` blocks CI. The kit defines nothing of its own.
- Screens still hold ~396 literals. `tool/check_tokens.sh` counts them. The count only
  goes down. [10c](features/10c-screen-restyle.md) sets `SCREENS_BLOCKING=1`.
- Brand color, logo, and app name come from `BrandConfig`.
- "Milano" appears in four allowed places only: `milano_orders.db`,
  `cafe-milano-backup-`, the `[MilanoOrders]` log tags, and `BrandConfig.milano`.
- All money goes through `lib/utils/money.dart`.
- No dark mode. No screen branches on `Theme.of(context).brightness`.

## Routes

`AppRoutes` constants in `lib/app.dart`, over a `StatefulShellRoute`.

| | |
|---|---|
| Shell branches | `/` home · `/orders` billing · `/kitchen` · `/profile` |
| Outside the shell | `/dashboard` · `/order/:shopId` · `/outstanding` · `/splash` |
| Under `/profile/*` | shops, products, prices, standing orders, business info, categories, backup, dashboard options, and the ledger at `/profile/shops/:id/ledger` |

[10b](features/10b-navigation.md) moves `/profile/*` to `/settings/*` with redirects,
adds a drawer, and makes `/dashboard` a branch. Read it before adding a route.
