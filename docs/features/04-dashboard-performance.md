# 04 — Dashboard query cleanup + repo hygiene

| | |
|---|---|
| **Target version** | `1.6.2+8` |
| **Type** | Fix |
| **Schema** | No change |
| **Status** | Ready |

## Why

The dashboard shipped in `1.5.0` works and looks right. Underneath, it issues far
more database work than it needs to — an N+1 loop, the same expensive aggregate run
twice per load, and five redundant stream subscriptions. None of it is visible at
today's data volume. All of it compounds with [doc 03](03-db-integrity.md)'s
trajectory and with [doc 12](12-dashboard-tabs.md), which adds more cards over the
same queries.

This is the last cleanup release before the ledger. It is optional in the sense
that nothing depends on it — if the ledger is urgent, this can slide behind doc 07.

## The specific problems

All line references are `lib/providers/dashboard_provider.dart`.

### 1. N+1 query in shop concentration

```dart
for (final row in rows) {                                    // :220
  final catIds = await db.dashboardDao
      .getShopCategoryIds(shopId, range.start, range.end);    // :226 — one query per shop
```

19 queries for 18 shops. Grows linearly with the shop count, inside a loop that
also awaits sequentially — so it is 19 serial round-trips, not 19 parallel ones.

### 2. The same aggregate runs twice per load

| Query | Called from | And from |
|---|---|---|
| `getShopConcentration()` | `shopConcentrationProvider:212` | `attentionFlagsProvider:359` |
| `getCategoryScores()` | `categoryScorecardsProvider:86` | `categoryMixProvider:159` |

Separate `FutureProvider`s, no shared result. Both cards render on the same screen,
so each of these expensive grouped aggregates executes twice on every dashboard
open and every range change.

### 3. Five redundant stream subscriptions

`db.categoryDao.watchActive().first` appears at lines 81, 155, 209, 250 and 309 —
five providers each spinning up a Drift query-stream, taking one value, and tearing
it down. It only ever needs to be a plain `get()`, fetched once and shared.

### 4. Range-independent providers invalidate on range change

`todayRevenueProvider`, `revenueDeltaProvider`, `shopsServedTodayProvider` and
`pendingConfirmationsProvider` each call `ref.watch(dashboardRangeProvider)` with
the comment `// dependency for refresh` — then ignore the value and query
`DateTime.now()`. Changing the date range re-runs four today-only queries whose
results cannot have changed.

### 5. `DateTime.now()` read inside providers

Scattered through the file (`:35`, `:42`, `:89`, `:276`, `:306`). Two consequences:
results are not reproducible in tests, and an app left open across midnight keeps
reporting the previous day as "today" until something else invalidates it.

## Action items

### Queries

- [ ] Collapse the N+1: replace the per-shop `getShopCategoryIds` loop with **one**
      grouped query returning `shopId → [categoryId]` for the whole range, then map
      in Dart. `getShopConcentration` already groups by shop; the category breadth
      can join into it or come back as a second single query.
- [ ] Introduce a shared `categoriesProvider` — a plain `FutureProvider` calling
      `get()` once. Have all five call sites watch it instead of
      `watchActive().first`. Riverpod caches it; this is exactly what providers are for.
- [ ] Extract `getShopConcentration` and `getCategoryScores` into their own
      `FutureProvider.family` keyed on the range, and have both consumers watch the
      provider rather than calling the DAO. One execution per range, shared.
- [ ] Introduce a `todayProvider` returning a midnight-normalised `DateTime`, and
      have the four Pulse providers watch **that** instead of
      `dashboardRangeProvider`. This removes the spurious invalidation and makes the
      day boundary explicit and overridable in tests.
- [ ] Replace every in-provider `DateTime.now()` with `ref.watch(todayProvider)`.
- [ ] Re-measure after doc 03's indexes land. Do not do both in one release —
      otherwise there is no way to attribute any change to either.

### Repo hygiene

Small, unrelated, and worth clearing while in the area rather than as their own release.

- [ ] Delete `assets/fonts/Poppins-*.ttf` — all four files, 632 KB. Superseded by
      Quicksand at commit `d9e6799`. They are **not** bundled (not declared in
      `pubspec.yaml`), so this is repo weight only, not APK weight. Confirm no
      lingering `Poppins` reference in `lib/` before deleting.
- [ ] `android/app/src/main/AndroidManifest.xml` — set `android:allowBackup="false"`
      on `<application>`. It currently defaults to **true**, so the business database
      is auto-synced into the user's Google Drive backup. For a single-user offline
      app holding supplier pricing, that should be a deliberate choice, and the app
      already has its own explicit Backup & Restore.
- [ ] `lib/services/backup_service.dart:57-60` — exported backups are written into
      `getTemporaryDirectory()` and never cleaned up. Delete the previous export
      before writing a new one, or sweep files older than a day.
- [ ] `lib/services/backup_service.dart:13-61` — export reads every product photo,
      base64-encodes it and `jsonEncode`s the whole structure **on the main
      isolate**. On the real dataset this is the 1.7 MB seen in doc 02, and it will
      visibly jank. Move the encode into `compute()`. Low risk, contained change.

## Success criteria

- [ ] Dashboard load issues a **fixed** number of queries regardless of shop count —
      verify by logging query counts with 18 shops and again with a fixture of 100.
- [ ] `getShopConcentration` and `getCategoryScores` each execute **once** per
      dashboard load, not twice.
- [ ] Changing the date range does not re-execute the four Pulse queries.
- [ ] Every dashboard number is identical to `1.6.1` on the same dataset. This is a
      refactor — any changed figure is a bug, and the criterion is exact equality,
      not "looks about right".
- [ ] Dashboard renders under 400 ms on the real dataset on a mid-range Android.
- [ ] Backup export no longer drops frames on the real dataset.
- [ ] `assets/fonts/` contains only the four Quicksand files; app typography is
      visually unchanged.
- [ ] Temporary directory holds at most one backup export after three consecutive
      exports.
