# Flutter practices & lifecycle audit — Milano Orders `1.9.1+12`

> Written 2026-08-27, against commit `60b9662`, schema v6.
> Scope: **framework-level correctness** — application lifecycle, widget lifecycle,
> async/context safety, and Riverpod architecture.
> Companion to [`app-audit.md`](app-audit.md), which covers structure, visual design
> and perceived performance. This document deliberately does not re-tread those.
> It describes what is, then proposes the migration.

---

## 0. The one-paragraph version

The data layer is sound and the app is disciplined about `mounted` in a way most
codebases this size are not. The problem is not ignorance of the right pattern — **the
right pattern is already in this repository**, in `shop_ledger_screen._exportStatement`
and `backup_restore_screen._export`: `setState` a busy flag, `try` the work, `catch`
into a SnackBar, `finally` clear the flag behind a `mounted` guard. That exact shape is
correct, and it appears in two places out of the twenty-three that need it. Everything
below is a variation on *the codebase disagrees with itself*.

Three things, though, are not style. They are defects:

1. **Order quantities typed in the last 500 ms before leaving order entry are silently
   discarded** (`dispose` cancels the debounce without flushing).
2. **A DB failure on the Kitchen screen renders as "No orders for this date."** The
   operator is told there is nothing to bake.
3. **An app left open overnight reports yesterday as today**, on every screen, forever.

---

## 1. Counted

Measured across `lib/` — 13,211 lines, 62 files.

| Signal | Count | Reading |
|---|---:|---|
| `StatefulWidget` files | 20 of 39 | Just over half of all UI files hold mutable state |
| `initState` overrides | 13 | |
| `dispose` overrides | 14 | |
| `didUpdateWidget` overrides | **0** | Every `widget.*`→`State` seed is a latent staleness bug |
| `didChangeDependencies` overrides | 2 | Both correct, both guarded |
| `WidgetsBindingObserver` / `didChangeAppLifecycleState` | **0** | The app never learns it was backgrounded |
| `FlutterError.onError` / `runZonedGuarded` / `ProviderObserver` | **0** | No crash or provider-error observability |
| `mounted` guards | 40 | Genuinely good hygiene |
| `try`/`catch` in `lib/screens` + `lib/widgets` | **3** | Against 23 UI-initiated DB calls |
| `maybeWhen(orElse:)` collapsing error into empty | 12 | §5.1 |
| `error: (e, _) => Text('Error: $e')` | 16 | Raw `toString()` on screen, no retry |
| Legacy `StateNotifierProvider` / `StateProvider` | 2 / 1 | |
| Modern `Notifier` / `AsyncNotifier` | **0** | |
| `ref.read(databaseProvider)` from UI | 23 across 12 files | No repository seam |
| `Theme.of(context)` reads | 8 | The theme is defined and then not used |
| Top-level `const Color` reads via `import app.dart` | 96 across 32 files | Colour resolved at compile time, not from the tree |

---

## 2. Application lifecycle

### 2.1 The `ProviderContainer` is never disposed — so the database is never closed

`lib/main.dart:13-21`

```dart
final container = ProviderContainer();
final db = container.read(databaseProvider);
...
runApp(UncontrolledProviderScope(container: container, child: const MilanoOrdersApp()));
```

`databaseProvider` registers `ref.onDispose(db.close)` (`lib/providers/database_provider.dart:6`).
That callback **can never fire**. The container is constructed by hand, handed to
`UncontrolledProviderScope` — which by contract does *not* own it — and nothing calls
`container.dispose()`. The SQLite handle is released only by process death.

On Android that is survivable most of the time. It stops being survivable the moment
backup/restore wants to swap the file underneath, or a future auth flow wants to tear
down and rebuild the container on sign-out.

### 2.2 Startup blocks the first frame on unbounded I/O, with no failure path

`lib/main.dart:14-19`

```dart
if (kDebugMode) {
  await seedFromBackup(db);      // reads dev/seed.json, restores the whole DB
} else {
  await seedDefaultCategories(db);
}
runApp(...);
```

Two problems. `runApp` is not reached until the seed completes, so the native splash is
held for the duration — and `seedFromBackup` restores an entire JSON backup through
`backupDao.restoreAll`, which is bounded only by the size of `dev/seed.json`. And there
is no `try`/`catch`: a throw here means `runApp` is never called and the user gets a held
splash that never resolves into an app. No first frame is ever built, so no in-app error
UI can possibly show.

### 2.3 The splash is removed before there is anything to show

`lib/main.dart:20-21` — `FlutterNativeSplash.remove()` runs on the line after `runApp`,
synchronously. `runApp` schedules the first frame; it does not await it. The native
splash is therefore torn down before the first frame is rasterised. The visible result
is a flash of blank surface between the native splash and `SplashScreen` — which is
itself a second, redundant splash (§3.1).

### 2.4 Nothing in the app knows it was backgrounded

Zero `WidgetsBindingObserver`. Three consequences, in ascending severity:

- No DB checkpoint or flush on `paused`/`detached`.
- Pending debounced order-entry writes are not flushed when the app goes to background.
- **"Today" is computed once and never recomputed.**

That third one is the real one, and it is worth stating precisely.

`selectedDateProvider` (`lib/providers/date_provider.dart:3-6`) and `todayProvider`
(`lib/providers/dashboard_provider.dart:38-41`) both evaluate `DateTime.now()` at first
read and cache it for the lifetime of the container. `todayProvider`'s own doc comment
says it exists so that "a session left open across midnight catches up instead of quietly
reporting yesterday forever" — but the only thing that invalidates it is pull-to-refresh
on the Dashboard (`dashboard_screen.dart:162`). `selectedDateProvider` is never
invalidated by anything at all.

This is a delivery business. The phone sits on a counter. It is left open overnight
routinely. The next morning, Home, Billing and Kitchen all show yesterday's date and
yesterday's orders, and nothing in the UI says so.

### 2.5 No error observability

No `FlutterError.onError`, no `PlatformDispatcher.instance.onError`, no
`runZonedGuarded`, no `ProviderObserver`. Every unhandled framework error, every
provider that fails to build, and every dropped Future in §3.3 goes to the console of a
device nobody is looking at. For a shipped APK distributed through GitHub Releases, that
is the entire diagnostic surface.

---

## 3. Widget lifecycle

### 3.1 Navigation from an animation callback, unguarded

`lib/screens/splash/splash_screen.dart:29-34`

```dart
_controller.addStatusListener((status) {
  if (status == AnimationStatus.completed) {
    context.go(AppRoutes.home);
  }
});
```

No `mounted` check. If the route is disposed during the 1200 ms animation — system back,
a deep link, a hot restart under test — this touches `context` on a defunct `State`.
The listener is also never removed; disposing the controller happens to make that
harmless, which is exactly why the pattern survives review.

Separately: this route exists on top of `flutter_native_splash`. The user watches two
splash screens in sequence for 1.2 s on every cold start. It buys nothing — no work is
performed during the animation.

### 3.2 Fire-and-forget async in `initState`, with no failure path

`lib/screens/order_entry/order_entry_screen.dart:46` calls `_init()` without awaiting or
catching. `_init` (`:50-98`) performs four sequential DAO calls and then `setState`s
`_loading = false`. **There is no `try`.** Any throw — a locked DB, a missing shop after
a restore, a schema surprise — leaves `_loading` permanently `true`. The user gets an
infinite spinner on the app's primary data-entry screen, with a back button that is
hardcoded to `context.go('/')` (`:243`), discarding the navigation stack.

`lib/screens/profile/profile_screen.dart:21-24` is the same class of problem in miniature:
`PackageInfo.fromPlatform().then(...)` with no `catchError`.

### 3.3 Database writes inside `setState` closures

`lib/screens/order_entry/order_entry_screen.dart:106-115`

```dart
setState(() {
  _qtys[productId] = qty;
  if (_isConfirmed) {
    _isConfirmed = false;
    ref.read(databaseProvider).orderDao.setConfirmed(_orderId!, false);
  }
});
```

Repeated at `:225-230` in `_loadStandingOrder`.

`setState`'s callback is contracted to be a synchronous, side-effect-free mutation of
state. Here it starts a database write whose `Future` is dropped on the floor: if
`setConfirmed` fails, the UI says the order is unconfirmed and the database says it is
confirmed, and nobody is told. The two states diverge permanently.

### 3.4 Debounced writes are cancelled, not flushed — data loss

`lib/screens/order_entry/order_entry_screen.dart:103-107`

```dart
@override
void dispose() {
  _debounce?.cancel();
  super.dispose();
}
```

`_setQty` schedules `_save()` 500 ms out (`:113-114`). Leaving the screen inside that
window cancels the timer and the quantities are gone. There is no flush, and no
`WidgetsBindingObserver` to catch the background case either (§2.4).

The confirm path calls `_save()` explicitly first (`:140,163`), so a confirmed order is
safe. An order the user edits and then backs out of — the common case for "I'll finish
this later" — is not. This is silent, and it is the app's core write path.

### 3.5 No `didUpdateWidget`, anywhere

Zero overrides, against three places that seed `State` from `widget.*` in `initState`:

- `order_entry_screen.dart:39-47` — `_date` parsed from `widget.date`
- `product_qty_row.dart:160-167` — digit wheels seeded from `widget.initialQty`
- `shop_ledger_screen.dart:488-493` — filter sheet seeded from `widget.initial`

All three are correct *today*, because each is entered fresh every time. Each becomes a
silent stale-data bug the first time its widget is rebuilt in place with new
parameters — a route parameter change, a list reorder, an `AutomaticKeepAlive`, a
`StatefulShellBranch` that retains state. The bug will not throw. It will render the old
value.

### 3.6 Uncancellable delayed work

`lib/widgets/staggered_fade_in.dart:31-33` — `Future.delayed` with no handle. The
`mounted` guard makes it safe, but the closure holds the `State` alive for up to 360 ms
past disposal and cannot be cancelled. In a fast-scrolled list that is a queue of dead
closures waking up to check `mounted`.

For contrast, `product_qty_row.dart:322-341` does this correctly: `Timer.periodic` held
in a field, cancelled on gesture end *and* in `dispose`. That is the pattern to
generalise.

### 3.7 `StatefulWidget` used where it is not needed

20 of 39 widget files. Several hold nothing that Riverpod could not:

- `kitchen_screen.dart:22-36` — a `TabController` and nothing else
- `shop_ledger_screen.dart:56-75` — a `TabController` plus three filter fields
- `orders_screen.dart:23-24` — a single `int? _expandedOrderId`

Not wrong. But each one is a `State` object whose lifecycle has to be reasoned about,
and §3.5 is the tax on having twenty of them.

---

## 4. Async and `BuildContext` safety

Credit where it is due: 40 `mounted` guards, and `use_build_context_synchronously` is
satisfied throughout. This is better than most.

The inconsistency is in *which* guard. `State.mounted` is used at 38 sites;
`context.mounted` at 2 (`category_list_screen.dart:121,143`). They are not the same
check — `State.mounted` says the `State` is alive, `context.mounted` says the element is
still in the tree — and the codebase does not distinguish. Both happen to be right here,
but "both idioms, no rule" is how the wrong one eventually gets picked.

The concrete gap is error handling. Three `try`/`catch` blocks in the UI layer against 23
UI-initiated DB calls, and the money path is one of the twenty:

`lib/screens/ledger/record_payment_sheet.dart:59-75`

```dart
setState(() => _saving = true);
...
await ref.read(databaseProvider).ledgerDao.recordPayment(...);
if (mounted) Navigator.pop(context);
```

No `catch`, no `finally`. If `recordPayment` throws, the sheet stays open with a
permanently disabled Save button and no message. The user's only recourse is to dismiss
the sheet, and they have no way to know whether the payment landed.

Compare `shop_ledger_screen.dart:126-153` and `backup_restore_screen.dart:19-31` — same
shape, done correctly, in the same feature area. The pattern exists. It just was not
applied here.

---

## 5. Riverpod architecture

### 5.1 Loading and error collapsed into "empty"

Twelve `maybeWhen(..., orElse: ...)` sites map *both* loading and error to a benign empty
value. Four of them are in one build method:

`lib/screens/kitchen/kitchen_screen.dart:41-57`

```dart
final shopMap = ref.watch(allShopsProvider).maybeWhen(
      data: (shops) => {for (final s in shops) s.id: s},
      orElse: () => <int, Shop>{},   // ← error and loading are the same thing here
    );
```

Kitchen then renders the empty state: **"No orders for this date."** A database failure
is indistinguishable from a genuinely empty day. In a bakery, that is the difference
between baking nothing and being told to bake nothing.

`orders_screen.dart:31-42` does it three times, including for `billDuesForDateProvider` —
so a failure to load payment status renders every bill as unpaid.

`attention_flags.dart:90` is the sharpest version: `error: (_, _) => const SizedBox.shrink()`.
The card whose entire job is to surface problems removes itself when it has a problem.

### 5.2 Two contradictory freshness models

Everything outside the dashboard is a `StreamProvider` over Drift `watch*` — genuinely
reactive, updates the instant a write lands, from anywhere.

The dashboard is fourteen `FutureProvider`s over one-shot reads. They are stale the
moment any order is written, and freshness is bolted back on by hand:

`lib/screens/dashboard/dashboard_screen.dart:161-175` — `_refreshDashboard` calls
`ref.invalidate` fourteen times, once per provider, in a hand-maintained list. Add a
fifteenth dashboard provider and forget the line, and it silently never refreshes. There
is no way for the analyzer or a test to catch that omission.

Drift's `watch*` already solves this. The dashboard opted out of it and rebuilt a worse
version by hand.

### 5.3 Legacy API only, and one settings provider that flashes and loses writes

Two `StateNotifierProvider`, one `StateProvider`, zero `Notifier`/`AsyncNotifier`. No
`riverpod_generator`, no `riverpod_lint`. `StateNotifier` is soft-deprecated in Riverpod
2 and gone in 3, so this is also a forward-compatibility problem.

`lib/providers/dashboard_settings_provider.dart:26-46` shows why the modern API exists:

```dart
DashboardSettingsNotifier() : super(const DashboardSettings()) {
  _load();   // async, un-awaited, fired from the constructor
}
```

The notifier publishes a **default** state immediately, then replaces it when
`SharedPreferences` resolves. Every section toggle renders ON for one or more frames and
then flips to its real value. That flash is not cosmetic — it is the provider telling the
UI something untrue.

Worse, `toggle()` (`:48-55`):

```dart
state = updated;
await _prefs?.setBool(key, value);   // ← null-safe call: silently no-ops
```

If a toggle is hit before `_load()` completes, `_prefs` is null, the `?.` swallows the
write, the UI updates, and **the setting is not persisted** — with no error and no
indication. `AsyncNotifier` makes this state unrepresentable: there is no notifier to
toggle until the load has resolved.

### 5.4 No data-access seam

`ref.read(databaseProvider)` appears at 23 sites across 12 screen and widget files. There
is no `lib/repositories/`. The UI reaches `AppDatabase`, then reaches a DAO on it, then
calls SQL-backed methods — from inside `build` and from inside gesture handlers.

The DAOs are `part of` the generated database (`app_database.dart:31-39`), so they cannot
be mocked independently. Any widget test that touches a write path has to stand up a real
`AppDatabase.forTesting`. The existing tests work around this by overriding the
*providers* instead — which works, and is the right instinct, but it means the provider
signatures are the de-facto architectural boundary while the code is written as though
they are not.

### 5.5 Theme and router resolved from globals, not from the tree

`lib/app.dart` is imported by 32 files, overwhelmingly to reach four top-level
`const Color` values. 96 references to `kBrandGold`/`kBrandBrown`/`kSurface`, against 8
`Theme.of(context)` reads in 13,211 lines. Colour is resolved at *compile time from a
global*, not from the widget tree.

That is the mechanism by which dark mode, a second brand (doc 17 — white-label), and any
runtime theme switch are currently impossible without editing 96 call sites. The
`ThemeData` at `app.dart:200-280` is real, complete, and almost entirely unread.

`_router` (`app.dart:60`) is a top-level global for the same reason and with the same
cost: it cannot be overridden in a test. Which is why `widget_test.dart:50-62` and
`navigation_test.dart:16-45` each hand-build a parallel route table that has to be kept in
sync with the real one manually. `navigation_test.dart` says so in its own header comment.

---

## 6. Migration plan

Six phases. Ordered so that each one is independently shippable, and so that the
guardrails that prevent regression land before the refactors that risk it.

Effort is in focused working days. Phases 0–2 are the ones that fix defects; 3–5 are the
ones that stop them recurring.

---

### Phase 0 — Guardrails · ~0.5 day · no behaviour change

Nothing here changes runtime behaviour. It makes the rest of the plan enforceable.

1. Add `riverpod_lint` + `custom_lint` to `dev_dependencies`, enable in
   `analysis_options.yaml`.
2. Turn on the rules this audit found violations of:

```yaml
linter:
  rules:
    - use_build_context_synchronously
    - discarded_futures          # catches §3.3
    - unawaited_futures
    - avoid_void_async
    - cancel_subscriptions
    - close_sinks
    - always_declare_return_types
```

3. Install a `SessionStart`-friendly `analyze` + `test` check so CI fails on new
   violations rather than on discovery.

**Done when:** `flutter analyze` is green with the new rules, or every remaining
violation carries an `// ignore:` with a reason and a link to the phase that removes it.

---

### Phase 1 — Application lifecycle · ~1 day · fixes §2

The highest-value phase. It closes the overnight-staleness defect.

1. **Own the container.** Drop the hand-built `ProviderContainer`; use `ProviderScope`
   with `overrides` for anything startup needs. If a pre-`runApp` handle is genuinely
   required, keep `UncontrolledProviderScope` but dispose the container in an
   `AppLifecycleListener.onExitRequested`/`onDetach`.
2. **Move seeding off the startup path.** `runApp` first; do the seed inside an
   `AsyncNotifier`-backed bootstrap provider that the root widget watches. Wrap it in a
   `try`, and render a real error screen on failure — which is now possible, because a
   first frame exists.
3. **Remove the splash *route*.** `flutter_native_splash` already covers cold start.
   Delete `SplashScreen`, make `/` the initial location, and call
   `FlutterNativeSplash.remove()` from the bootstrap provider's first successful data
   state — not from the line after `runApp`.
4. **Add one `AppLifecycleListener`** at the root. On `resumed`: invalidate
   `todayProvider` and, if the date rolled over, `selectedDateProvider`. On `paused`:
   flush pending writes (Phase 2 gives this a home).
5. **Make "today" self-correcting.** Convert `todayProvider` to a `Notifier` that
   invalidates itself on a timer scheduled for the next local midnight, in addition to
   the resume hook. Belt and braces — the timer covers an app that stays foregrounded,
   the resume hook covers one that does not.
6. **Add error observability.** `FlutterError.onError`,
   `PlatformDispatcher.instance.onError`, and a `ProviderObserver` that logs
   `providerDidFail`. Local logging is sufficient to start; the seam is what matters.

**Done when:** an integration test that advances the clock across midnight and fires
`AppLifecycleState.resumed` sees Home report the new date.

---

### Phase 2 — Close the three defects · ~1 day · fixes §3.2–3.4, §4

Small, surgical, high value. Deliberately separated from Phase 4's broader cleanup so it
can ship on its own.

1. **Flush the debounce.** Extract order-entry save into a small `OrderDraftController`
   (a `Notifier`) that owns the timer and exposes `flush()`. Call `flush()` from
   `dispose`, from the `AppLifecycleListener`'s `paused`, and from confirm. Cancel-only
   disposal goes away.
2. **Get DB writes out of `setState`.** The `setConfirmed` calls at
   `order_entry_screen.dart:110` and `:228` move into the controller, awaited, with the
   local flag updated *after* the write succeeds and an error surfaced if it does not.
   `discarded_futures` from Phase 0 will not let this regress.
3. **Give `_init` a failure path.** `try`/`catch` around it; on failure set an error
   field and render a retry, not a spinner. Or — better, and the direction Phase 3
   goes — replace `_init` + six `State` fields with one `AsyncNotifier` whose
   `AsyncError` state the screen renders.
4. **Apply the existing correct pattern to `record_payment_sheet._save`.** `try`/`catch`
   into a SnackBar, `finally` clear `_saving` behind a `mounted` guard. Copy
   `shop_ledger_screen.dart:126-153` verbatim; it is already right.
5. Sweep the remaining ~19 unguarded UI-initiated DB calls with the same shape.

**Done when:** a test that pops order entry 100 ms after a quantity change finds the
quantity in the database.

---

### Phase 3 — `AsyncValue` discipline · ~1 day · fixes §5.1

1. **Delete every error-swallowing `orElse`.** Twelve sites. Where a screen needs several
   providers, compose them into one derived provider that returns a record, and let the
   screen `.when` on the single `AsyncValue` — one loading state, one error state, one
   data state, instead of four independent `maybeWhen`s in a build method.
2. **Three shared widgets**, used everywhere: `AppErrorView` (message, cause, retry
   callback), `AppLoadingView`, `AppEmptyView`. This is what replaces the 16
   `Text('Error: $e')` sites, and it is what makes "empty" and "failed" visually
   distinct — which is the actual Kitchen bug.
3. **Log before rendering.** Every error branch reports to the Phase 1 observer. Stack
   traces stop being discarded via `(e, _)`.
4. `attention_flags.dart` renders a failed state instead of vanishing.

**Done when:** no `orElse` in `lib/screens` or `lib/widgets`, and a test that overrides a
provider with `Stream.error(...)` sees an error view on Kitchen, not the empty state.

---

### Phase 4 — Riverpod modernisation · ~2 days · fixes §5.2, §5.3

1. **Adopt `riverpod_generator`.** Migrate providers to `@riverpod` incrementally — it
   interoperates with the hand-written ones, so this does not need a big-bang cut.
2. **`StateNotifier` → `Notifier` / `AsyncNotifier`.** `DashboardSettingsNotifier`
   becomes an `AsyncNotifier`: no default-state flash, no null `_prefs`, no silently
   dropped write. `DashboardRangeNotifier` and `selectedDateProvider` become `Notifier`s.
3. **Retire `_refreshDashboard`.** Convert the fourteen dashboard `FutureProvider`s to
   `StreamProvider`s over Drift `watch*` queries, matching the rest of the app. The DAOs
   already return the right shapes; `dashboard_dao.dart` needs `watch` variants alongside
   its `get` ones. Pull-to-refresh becomes a no-op the UI can keep for feel, and the
   hand-maintained invalidation list is deleted rather than extended.
   *If any aggregate turns out too expensive to stream, keep it a `FutureProvider` but
   make it depend on a cheap watched "revision" provider — the dependency graph does the
   invalidating, not a list a human has to remember.*

**Done when:** `_refreshDashboard` is gone, and writing an order from Order Entry updates
a visible Dashboard card with no user action.

---

### Phase 5 — Widget lifecycle & data seam · ~2 days · fixes §3.5–3.7, §5.4

1. **`lib/repositories/`.** One repository per aggregate (orders, shops, products,
   ledger, prices), each taking `AppDatabase` and exposing intent-shaped methods.
   Providers depend on repositories; the UI depends on providers; `databaseProvider`
   stops being reachable from `lib/screens`. This is what makes DAO-level behaviour
   mockable without standing up a database.
2. **Add `didUpdateWidget`** to the three `initState`-seeding widgets, or remove the need
   by lifting their state into providers. Prefer the latter where the state outlives the
   widget (order entry's `_date`), the former where it does not (the filter sheet).
3. **`StatefulWidget` → `ConsumerWidget`** where the only state was a `TabController`
   (Kitchen, Shop Ledger) or a selection `int` (Orders). `TabController` moves to
   `DefaultTabController`; the selection int moves to a scoped provider.
4. **`StaggeredFadeIn`** takes a cancellable `Timer` field, cancelled in `dispose` —
   matching the `product_qty_row` pattern.
5. Standardise on `context.mounted` after any `await` that is followed by a `context`
   use; `State.mounted` only for `setState`.

**Done when:** `grep -r 'databaseProvider' lib/screens lib/widgets` returns nothing.

---

### Phase 6 — Theme and router from the tree · ~1.5 days · fixes §5.5

Overlaps heavily with doc [10a — design system](features/10a-design-system.md); sequence
them together and treat this as 10a's mechanical half.

1. **`ThemeExtension`s** for brand colour, spacing, radius and type scale. Registered on
   `ThemeData`, read via `Theme.of(context).extension<…>()`.
2. **Migrate the 96 global-colour reads** to theme reads, file by file. The 32 `import '../../app.dart'` lines disappear with them.
3. **Extract `ThemeData`** out of `MilanoOrdersApp.build` into `lib/theme/`, so it is
   constructed once rather than rebuilt with the root.
4. **`_router` becomes `routerProvider`.** The two tests stop hand-maintaining parallel
   route tables and override the real one instead — which also means
   `navigation_test.dart`'s duplicate-page-key rule is finally being tested against the
   actual router.

**Done when:** flipping `ThemeData.brightness` produces a coherent dark app, and both
test files reference the production route table.

---

## 7. Sequencing

```
Phase 0  Guardrails          ░ 0.5d   ← land first; makes everything else enforceable
Phase 1  App lifecycle       ██ 1d    ← fixes the overnight-staleness defect
Phase 2  The three defects   ██ 1d    ← fixes the data-loss defect
Phase 3  AsyncValue          ██ 1d    ← fixes the "nothing to bake" defect
Phase 4  Riverpod modern     ████ 2d
Phase 5  Lifecycle + repos   ████ 2d
Phase 6  Theme + router      ███ 1.5d ← pair with doc 10a
                             ─────
                             ~9 days
```

Phases 0–3 are ~3.5 days and close every defect named in §0. If only one block of work
gets done, it should be that one. Phases 4–6 are the structural work that keeps them
closed, and 6 should be scheduled with the UI overhaul rather than ahead of it.

Each phase is independently shippable and independently revertable. None of them require
a schema change.

---

## 8. What is already right

Worth recording, so the migration does not "fix" it:

- **Drift usage.** Real migration chain, v4→v6 upgrade path with orphan cleanup, indexes
  created deliberately with a documented rationale for single-column over composite.
- **`mounted` hygiene.** 40 guards. `use_build_context_synchronously` is satisfied.
- **`didChangeDependencies`.** Both uses (`floating_nav_bar.dart:52`,
  `staggered_fade_in.dart:19`) are guarded against re-entry and correctly chose
  `didChangeDependencies` over `initState` for `MediaQuery` access. The comment explaining
  why is exactly the right comment.
- **Reduced-motion support.** `MediaQuery.disableAnimations` is honoured in four widgets.
  Most apps this size do not do this at all.
- **The error-handling shape** in `shop_ledger_screen._exportStatement` and
  `backup_restore_screen._export`. Phase 2 is largely "apply this, everywhere".
- **`Timer` ownership** in `product_qty_row.dart:322-341`.
- **Provider signatures** are stable and override-friendly, which is what makes the
  existing test suite possible and what will make the repository seam cheap to insert.
- **`ShopLedgerQuery` as a record family key** (`ledger_provider.dart:9-14`) — structural
  equality for free, with the reason written down. Correct and non-obvious.

The foundation is not the problem. The layer directly above it grew one screen at a time,
and this document is the list of places where that shows.
