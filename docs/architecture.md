# Architecture

Facts. [`AGENTS.md`](../AGENTS.md) has the rules. Update this file with the code.

> `1.10.0+14` + 10b on `release/1.11.0-navigation` · schema v6 · 2026-08-29

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
  main.dart          runApp, error handlers. No work before the first frame
  app.dart           AppRoutes, the route table, legacyRedirectFor
  database/
    app_database.dart  @DriftDatabase, schemaVersion, migrations, indexes
    app_database.g.dart  generated — do not edit
    tables/  daos/  seed_data.dart  dev_seed.dart
  models/            dashboard_models.dart
  providers/         ~35 providers
  repositories/      does not exist yet — doc 14a
  screens/           dashboard finances home kitchen ledger order_entry orders settings
  services/          backup catalog_share category_emoji ledger_statement pdf_brand update
  theme/             tokens.dart brand_config.dart app_theme.dart
  utils/money.dart   the one currency formatter
  widgets/ui/        the component kit, 18 components, CI-gated
  widgets/shell/     shell, drawer, quick actions, shop picker, destinations
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
| `AppType` | 8 steps, wired into `ThemeData.textTheme`. Bricolage Grotesque, four bundled weights |
| `AppSpace` | `s1`–`s6` = 4, 8, 12, 16, 24, 32. Plus `page` |
| `AppRadius` | Corner scale |
| `AppShadow` | Elevation |

- No color, font size, radius, or shadow literal in `lib/screens/` or `lib/widgets/`.
- `lib/widgets/ui/` blocks CI. The kit defines nothing of its own.
- Screens still hold **354** literals, down from 396. `tool/check_tokens.sh` counts
  them. The count only goes down. [10c](features/10c-screen-restyle.md) sets
  `SCREENS_BLOCKING=1`.
- Brand color, logo, and app name come from `BrandConfig`.
- "Milano" appears in four allowed places only: `milano_orders.db`,
  `cafe-milano-backup-`, the `[MilanoOrders]` log tags, and `BrandConfig.milano`.
- All money goes through `lib/utils/money.dart` — symbol *and* digit grouping.
  `en_IN` groups as `1,16,717`; a literal `₹` with `NumberFormat('#,##0')` prints
  `116,717`, which is what 23 sites did before `money_test.dart` pinned it.
- No dark mode. No screen branches on `Theme.of(context).brightness`.

## Analyzer guardrails

`analysis_options.yaml`, on since [18](features/18-foundation-guardrails.md).

| Rule | Catches |
|---|---|
| `discarded_futures` · `unawaited_futures` | A future nobody waits for. A DB write that fails silently reads exactly like one that worked |
| `use_build_context_synchronously` | `context` used after an `await`, when the widget may be gone |
| `avoid_void_async` · `cancel_subscriptions` · `close_sinks` · `always_declare_return_types` | Leaks and hygiene. Zero violations today |

- Fire-and-forget is written `unawaited(...)`, never left bare. Haptics, share
  sheets, modal sheets, animation controllers and `initState` loaders all qualify.
- Two `// ignore: discarded_futures` remain, both in `order_entry_screen.dart` —
  DB writes inside `setState`. [10c](features/10c-screen-restyle.md) owns them.
- `deprecated_member_use_from_same_package` is 10c's progress bar. **77 today**, from 84.
- `riverpod_lint` is deliberately absent. It needs `custom_lint` 0.7.x, which pins
  analyzer 7.x, which drags drift 2.34 to 2.29 and sqlite3 3.3.3 to 2.9.4.
  Revisit at riverpod 3.

## Routes

`AppRoutes` constants in `lib/app.dart`, over a `StatefulShellRoute`.

| | |
|---|---|
| Shell branches | `/` overview · `/orders` · `/kitchen` · `/billing` · `/finances` |
| Pushed over the shell | `/settings` · `/settings/*` · `/outstanding` · `/shops/:id/ledger` · `/order/:shopId` |
| Under `/settings/*` | shops, products, prices, standing orders, business info, categories, backup, dashboard options |

Four rules, all from [10b](features/10b-navigation.md):

1. **The five branches are the five bottom-bar slots**, in the order of the
   day: see what happened, enter today's orders, bake them, bill them, collect.
   `bottomBarRoutes` in `widgets/shell/destinations.dart` and the branch order in
   `app.dart` must match — index 0-4 is the contract between them, and
   `test/routing_test.dart` asserts it. There is no centre FAB: each of its
   three former actions sits on the screen it belongs to.
2. **Settings children are siblings, not children, of `/settings`.** One page per push,
   so back from a drawer destination lands on the tab it was opened from rather than
   costing a second press to leave a Settings page nobody asked for.
3. **The ledger is top level**, at `/shops/:id/ledger`. A route nested under the
   `StatefulShellRoute` cannot be pushed from a top-level route — go_router keys the
   shell's page off the shell route object, so re-entering it trips Navigator's
   duplicate-page-key assertion. It used to be registered twice to dodge this.
   `test/navigation_test.dart` pins it.
4. **Never write a route string.** Use `AppRoutes` constants, and the builders
   (`shopLedgerFor`, `shopEditFor`, `productEditFor`, `orderEntryFor`) for anything
   with a `:param`. Hand-filled ids are how 30 raw `/profile` strings accumulated.

`legacyRedirectFor` in `app.dart` keeps every pre-10b `/profile/*` URL, the deleted
`/splash`, and the renamed `/dashboard` working. The branch paths were renamed in
1.11 because the old ones said the opposite of what they held: `/` was the shop list
and `/orders` was billing. `test/routing_test.dart` enumerates all of them. Delete it only once
no installed build can still hold an old link.

### Adding a destination

One row in `widgets/shell/destinations.dart`. The drawer, the bottom bar and the
settings search all read that list and nothing else. Set `shipped: false` until the doc
that builds it lands — unshipped destinations are hidden, never shown-disabled.

## App lifecycle

Since [10b](features/10b-navigation.md), absorbing Phase 1 of the lifecycle audit.

| Piece | Where | Does |
|---|---|---|
| `bootstrapProvider` | `providers/bootstrap_provider.dart` | Opens the database and seeds, under a live tree so a failure can render a retry |
| `AppBootstrapGate` | `widgets/shell/` | Holds the native splash up, removes it on a post-frame callback — onto the first real frame or onto the error screen |
| `AppLifecycleScope` | `widgets/shell/` | The app's **only** `AppLifecycleListener`. Resume re-derives today; pause flushes pending writes |
| `todayProvider` | `providers/date_provider.dart` | `Notifier` with a midnight timer. Reads `package:clock`, so the rollover is testable |
| `PendingWrites` | `providers/pending_writes.dart` | Debounced screen writes that must land before the process is suspended |
| `installErrorHandlers` | `services/error_reporting.dart` | `FlutterError.onError`, `PlatformDispatcher.onError`, and a `ProviderObserver` |

- `main()` does no work before `runApp`. A throw there produces a native splash that
  never resolves, with no error and nothing to report.
- Wall-clock reads that decide *what day it is* go through `package:clock`, not
  `DateTime.now()`.
- A screen holding a debounced write registers with `pendingWritesProvider` in
  `initState` and unregisters in `dispose`. `dispose` covers leaving the screen;
  registration covers the process being suspended, which does not call `dispose`.

## Lists

Three rules, all learned the hard way in 1.11.

1. **A fade or a transition belongs on the list, not in `itemBuilder`.**
   `itemBuilder` runs every time a row scrolls into view, so an animation
   started there restarts per row, forever, and every `Opacity` frame forces a
   `saveLayer`. Use `ListFadeIn` around the list. This was the scroll stutter.
2. **Any `Image.file` or `Image.asset` in a row needs `cacheWidth`.** A camera
   photo decoded at full resolution to be drawn at 40x40 janks the scroll
   thread.
3. **Rows get a `RepaintBoundary`.** The kit's `ListRow` has one; anything
   hand-rolled needs its own.

The three masters — Shops, Products, Categories — are built on
`MasterListPage`, which owns the header, `AppSearchField` and the `StatBand`.
A master screen supplies only its filter predicate. Row state is a
`StatusBadge`, never a tappable chip; the row opens the thing; actions are
labelled buttons in the row's footer.
