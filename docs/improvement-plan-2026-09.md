# Improvement plan — Milano Orders

> Written 2026-09-05, against commit `b5618c3`, version `1.10.0+14`, schema v6.
> The companion to [`code-review-2026-09.md`](code-review-2026-09.md), which is
> the findings list. This document is the work.
>
> Every block below is independently shippable and independently revertable.
> Effort is in focused working days for one developer who knows the codebase.
> None of blocks A–D require a schema change. Block F does, and is the only one
> that does.

---

## 0. The shape of the plan

Six blocks, ordered so that each one makes the next one cheaper.

```
A  Make the suite mean something     ░ 0.5d   ← nothing else is safe without it
B  Six small defects                 ██ 1d    ← highest value per hour in the repo
C  The repository seam               ████ 2d  ← the unlock for D and for doc 14
D  AsyncValue discipline             ██ 1d    ← closes the "nothing to bake" defect
E  Performance, where it is felt     ██ 1d
F  Money as integer paise            ██████ 3d ← schedule deliberately, not opportunistically
                                     ──────
                                     ~8.5 days
```

**If only one block gets done, do A.** It is half a day and it is what stops
everything else from silently regressing.

**If two, do A and B.** Together they are a day and a half, and they close every
finding that can lose the owner's data or leave them looking at a screen that is
lying to them.

Blocks C, D and E are the structural work that keeps those closed. F is a
separate decision, argued in its own section.

---

## A · Make the test suite mean something

**~0.5 day · no code change · no behaviour change**

There are 324 test cases across 6,735 lines. They are concentrated on money,
migrations, routing and lifecycle — exactly the right places. Nothing runs them.
`.github/workflows/release.yml` builds and publishes an APK straight from
`master` without so much as an analyze pass.

This block is the highest value-per-hour change available, and it is entirely
mechanical.

### The work

1. **Add `.github/workflows/ci.yml`.** Triggers on `pull_request` and on push to
   `master` and any `release/*` branch. Steps: `flutter pub get`,
   `dart run build_runner build --delete-conflicting-outputs`,
   `flutter analyze --fatal-infos`, `flutter test`.

2. **Wire `tool/check_tokens.sh` in as a step.** It already exits non-zero when
   the kit leaks a literal and reports without failing for the screens. Its own
   header says it is written to run in CI. Run it.

3. **Make CI a required check on `master`.** Without this the workflow is
   decoration.

4. **Make the release workflow depend on it.** `release.yml` currently builds an
   APK regardless. Add `needs: [ci]`, or repeat `analyze` and `test` in it. A
   red suite must not reach the owner's phone.

5. **Fix the release-notes heredoc** while in the file. `release.yml:96-105`
   uses a fixed `NOTES_EOF` delimiter around `git log` output. Use a random one.
   *(Finding 23.)*

### Why this first

Blocks B through F all change code that the existing tests cover. Doing them
without a gate means finding out about a regression when the owner does, at
5 a.m., with eighteen shops waiting.

### Done when

A pull request with a deliberately broken test cannot be merged, and a push to
`master` with a failing analyze does not publish an APK.

---

## B · Six small defects

**~1 day · fixes findings 4, 5, 6, 9, 10, 11, 12, 18**

Every item here is small, local, and closes something that either loses data or
shows the user something untrue. None of them wait on any other block. Ship them
as one release.

### B1 · Copy picked photos out of the cache · *finding 4*

`product_form_screen.dart:85-86`, `business_info_form_screen.dart:50-51`.

`ImagePicker` returns a path in the app's cache directory. That path goes into
the database and is treated as permanent. Android empties that directory
whenever it wants. The photos then vanish, the `errorBuilder` hides the failure,
and the next backup writes them out of existence.

Add one helper in a service:

```dart
/// Copies a picked image into permanent app storage and returns the new path.
/// The picker writes to the cache directory, which Android reclaims at will.
Future<String> persistPickedImage(XFile picked, {required String name}) async {
  final dir = Directory(p.join(
    (await getApplicationDocumentsDirectory()).path, 'photos',
  ));
  await dir.create(recursive: true);
  final out = File(p.join(dir.path, '$name${p.extension(picked.path)}'));
  await File(picked.path).copy(out.path);
  return out.path;
}
```

Call it from both pick handlers. Delete the previous file when a photo is
replaced or cleared. `importBackup` already does the same thing on the restore
path (`backup_service.dart:152-170`) — this is the write path catching up.

**One-off migration:** existing rows point at cache paths that may already be
dead. On first run after this ships, walk `products.photoPath` and
`business_info.logoPath`; copy any file that still exists into the new
directory and rewrite the path, and null out the ones that are already gone.
Put it in `bootstrap_provider.dart`, guarded by a `SharedPreferences` flag so it
runs once.

### B2 · Error handling on the two money writes · *finding 5*

`record_payment_sheet.dart:60-73` and `shop_ledger_screen.dart:190-202`.

Copy the shape that is already correct forty lines up in the same file —
`shop_ledger_screen._exportStatement` at `:131-159`:

```dart
setState(() => _saving = true);
try {
  await ...;
  if (!mounted) return;
  Navigator.pop(context);
} catch (e, s) {
  reportError(e, s, context: 'record payment');
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not save the payment: $e')),
    );
  }
} finally {
  if (mounted) setState(() => _saving = false);
}
```

Do the same for the delete. Then sweep the remaining unguarded UI-initiated
writes — the product, shop, category and business-info forms — with the same
shape. That sweep is roughly twenty call sites and is the bulk of this block's
day.

Block C moves these into repositories later. Do not wait for it: an unhandled
throw on the payment path is live now and the fix is not wasted work.

### B3 · Reject traversal in backup keys · *finding 6*

`backup_service.dart:161-180`. Image keys come from the imported file and are
joined onto a directory path without a check. `product_1./../../../foo` escapes
`imported_photos`.

```dart
final safeName = p.basename(imageKey);
if (safeName != imageKey || safeName.contains('..')) {
  throw InvalidBackupException('This backup contains an invalid image entry.');
}
```

Apply at both the product and logo sites. Add a test with a hostile key — there
is no such test today.

While in the file: `backup['schemaVersion'] as num` at `:145` throws a raw
`CastError` rather than `InvalidBackupException` when the field is a string.
Use `is num` and throw the friendly one.

### B4 · Survive an unknown payment mode · *finding 9*

`ledger_dao.dart:447`. `PaymentMode.values.byName(...)` throws on an unrecognised
string and takes the whole `watchShopLedger` stream down with it — the ledger
screen and the statement export both break permanently.

```dart
PaymentMode _modeFrom(String raw) =>
    PaymentMode.values.firstWhere(
      (m) => m.name == raw,
      // A mode this build does not know is display-only. It must never take
      // the ledger stream down: the amounts are still correct without it.
      orElse: () => PaymentMode.cash,
    );
```

Report through `reportError` when the fallback fires, so it is not invisible.

### B5 · Guard the router · *finding 10*

`app.dart:225, 241, 289, 295`. `int.parse` inside a route builder throws a
`FormatException` on `/shops/abc/ledger` and there is no `errorBuilder`, so the
user gets the framework's red screen.

Add a small helper beside the other builders in `AppRoutes`, use `int.tryParse`,
and redirect to the branch root when it fails. Add `errorBuilder` to
`buildRouter()` rendering `AppErrorView` with a "Go home" action.

Same treatment for `order_entry_screen.dart:85-87`, which splits the `date`
query parameter and indexes three parts without checking the split produced
three. Fall back to today.

`routing_test.dart` already exists and is the right home for the cases.

### B6 · Failure path for order entry's `_init` · *finding 11*

`order_entry_screen.dart:95-144`. No `try`. Any throw leaves `_loading` true and
the user gets an infinite spinner on the app's primary data-entry screen.

Add an `Object? _initError` field, `try`/`catch` around the body, and render
`AppErrorView` with a retry that calls `_init()` again. Roughly fifteen lines.

Block C's `AsyncNotifier` refactor supersedes this properly. This is the cheap
version that stops the bleeding now.

### B7 · Orphan-safe restore · *finding 12*

`backup_dao.dart:96-125` scrubs orphans for `shopPrices` and `standingOrders`
only. A v4-era backup carrying an orphaned `order_lines` row trips the FK
constraint and rolls back the entire restore — after the user has been told
their data will be erased.

Extend the same id-set filter to `dailyOrders` (→ shops), `orderLines`
(→ dailyOrders, products), `payments` (→ shops) and `paymentAllocations`
(→ payments, dailyOrders). Count what was dropped and report it in the success
dialog, rather than silently.

### B8 · Constrain the update URL · *finding 18*

`update_service.dart:75`. Before returning the `UpdateInfo`, require the URL to
parse, to be `https`, and to have a GitHub host. Throw
`UpdateCheckException('The latest release has an unexpected download link.')`
otherwise. Four lines, and it means the app can never point the user's browser
somewhere unexpected on a flow whose next step is installing an APK.

### Done when

- A test restores a backup whose image key contains `..` and gets
  `InvalidBackupException`.
- A test pops the record-payment sheet with a DAO that throws and finds the
  sheet still open with a message and an enabled Save button.
- A test navigates to `/shops/abc/ledger` and lands somewhere real.
- Picking a product photo, clearing the app's cache, and reopening the product
  list still shows the photo.

---

## C · The repository seam

**~2 days · fixes finding 2 · unblocks D and doc 14**

`AGENTS.md` rule 2 says a screen must never call `databaseProvider`. It is broken
at **30 sites across 14 files**, and the count has risen from 23 in five weeks.
The rule is losing.

This is `docs/features/14a-repository-seam.md`. It is listed here because the
review found it is now the binding constraint: it is why B2's error handling has
no shared home, why the write paths cannot be tested without a real database, and
why doc 14's Supabase port would touch fourteen screen files.

### The work

1. **Create `lib/repositories/`.** One repository per aggregate — orders, shops,
   products, ledger, prices, categories. Each takes an `AppDatabase` and exposes
   intent-shaped methods (`recordPayment`, `saveProduct`, `replaceOrderLines`),
   not DAO passthroughs.

2. **One provider per repository**, depending on `databaseProvider`. Existing
   providers depend on repositories instead of on the database directly. **No
   existing provider signature changes** — `AGENTS.md` rule 8 forbids it, and
   the whole point is that the screens do not notice.

3. **Migrate the 30 call sites**, one screen file at a time, each as its own
   commit. Order entry last: it is the largest and the one with the debounce.

4. **Put B2's error handling in the repository**, so a failed write returns a
   typed result or throws a domain exception the screens can render uniformly.

5. **Extract `OrderDraftController`** as the last step. A `Notifier` that owns
   `_qtys`, the debounce timer and `flush()`. This is what finally removes the
   two `// ignore: discarded_futures` database writes inside `setState`
   (`order_entry_screen.dart:181, 289`) — the honest markers doc 10c left behind.

6. **Delete the `databaseProvider` import** from `lib/screens` and
   `lib/widgets`, and add a grep to `tool/check_tokens.sh` so it cannot come
   back.

### Done when

`grep -rn 'databaseProvider' lib/screens lib/widgets` returns nothing, and CI
fails if it ever returns something again.

---

## D · `AsyncValue` discipline

**~1 day · fixes findings 8, 16**

19 `maybeWhen(orElse:)` sites collapse loading *and* error into a benign empty
value, up from 12 at the last audit. The sharpest is
`kitchen_screen.dart:45-60`: a database failure renders "No orders for this
date." **The baker is told there is nothing to bake.**

`AppErrorView` was built for this and is used by the bootstrap gate and almost
nowhere else.

### The work

1. **Delete every error-swallowing `orElse` in `lib/screens`.** Where a screen
   needs several providers — Kitchen needs four — compose them into one derived
   provider returning a record, and let the screen `.when` on a single
   `AsyncValue`. One loading state, one error state, one data state, instead of
   four independent `maybeWhen`s in a build method.

2. **Adopt `AppErrorView` and `AppSkeleton` everywhere.** Empty and failed must
   look different. That is the actual Kitchen bug.

3. **Log before rendering.** Every error branch reports through
   `reportError`. Stack traces stop being discarded via `(e, _)`.

4. **Retire `_refreshDashboard`.** `dashboard_screen.dart:196-209` invalidates 14
   providers from a hand-maintained list. Convert the twelve dashboard
   `FutureProvider`s to `StreamProvider`s over new `watch*` variants in
   `dashboard_dao.dart` — the shapes are already right. Pull-to-refresh becomes
   a no-op the UI can keep for feel, and the list is deleted rather than
   extended.

   *If an aggregate turns out too expensive to stream, keep it a
   `FutureProvider` but make it depend on a cheap watched revision provider. The
   dependency graph does the invalidating, not a human.*

5. **Finish the Riverpod modernisation while here.**
   `dashboardSettingsProvider` becomes an `AsyncNotifier`, which removes both
   halves of finding 21 — the default-state flash and the silently dropped
   write — by making them unrepresentable. `dashboardRangeProvider` and
   `selectedDateProvider` become `Notifier`s, matching `TodayNotifier` beside
   them.

### Done when

No `orElse` in `lib/screens` or `lib/widgets`; a test that overrides a provider
with `Stream.error(...)` sees an error view on Kitchen rather than the empty
state; and writing an order updates a visible dashboard card with no user
action.

---

## E · Performance, where it is felt

**~1 day · fixes findings 13, 14, 15, 22**

The big render costs from the earlier audits are genuinely gone. What is left is
concentrated on two screens and one feature.

### E1 · Cap the decode in order entry · *finding 13*

`product_qty_row.dart:57-62` draws a camera photo into a 48×48 box with no
`cacheWidth`. A 12-megapixel image decodes to roughly 48 MB, per row, on the
scrolling thread, on the screen the owner uses every morning.

`product_list_screen.dart:236-245` already fixed exactly this and left a comment
explaining the cost. Apply the same two lines here, and at
`product_form_screen.dart:204` and `business_info_form_screen.dart:119`.

**This is the single cheapest performance fix in the repository.** Do it in
block B if there is room.

### E2 · Batch the order-line write · *finding 14*

`order_dao.dart:69-78`. `replaceOrderLines` deletes every line then inserts the
non-zero ones one statement at a time. It runs 500 ms after every tap.

Wrap the inserts in Drift's `batch()`. Same for `upsertOrderWithLines` at
`:54-67`.

Then, if E2 alone is not enough: write only the lines that changed. The debounce
already knows which product ids moved. This is a larger change and belongs after
block C, when `OrderDraftController` owns that state.

### E3 · Batch the restore, bound the export · *finding 15*

`backup_dao.dart:126-143` inserts `dailyOrders`, `orderLines` and
`paymentAllocations` row by row — roughly 6,500 sequential awaited inserts for a
year of trading. Use `batch()`.

`backup_service.dart:34-96` holds every table, every photo and one large JSON
string in memory at once, then copies the lot across an isolate boundary. Peak
memory is about three times the photo set. With 28 photos at 4 MB that is a
plausible out-of-memory on a low-end phone.

The clean fix is to stop embedding photos as base64 and write a zip — the
database JSON plus the image files beside it. That changes the backup format, so
it needs a version bump and a reader for the old format. Budget it separately if
the owner's photo set is large; batch the restore either way.

### E4 · Cheaper outstanding · *finding 22*

`ledger_dao.dart:267-304` runs correlated subqueries per shop and watches five
tables, so it re-runs on every order-line write — including every 500 ms
order-entry save, while the drawer keeps it permanently subscribed.

Fine at 18 shops. Revisit only if the drawer card is measurably costing frames.
Listed for completeness, not scheduled.

### Done when

Order entry scrolls at 60 fps with photos on every product, and a full restore
of a year's data completes in a few seconds rather than tens of seconds.

---

## F · Money as integer paise

**~3 days · fixes finding 3 · schema v7 · schedule deliberately**

Every money column is a `REAL`. `ledger_dao.dart:7` carries a `_moneyEpsilon` of
0.005 and routes seven comparisons through it, because
`sum(allocations) == orderTotal` can be false by 1e-13. The comment says exactly
that. The workaround is correct and the tests prove it works.

The problem is that it must be applied everywhere, forever, by every future
author. One already slipped: `watchShopStats` (`:487`) computes
`openingBalance + totalBilled - totalCollected` with no epsilon, so a shop that
has paid to the last paisa can carry a balance of 1e-10 on its own ledger screen.

### The argument for doing it

Money is the app's entire purpose. Integer paise makes comparisons exact,
deletes `_moneyEpsilon` rather than maintaining it, and removes the class of bug
instead of managing it. It gets more expensive with every row the business
writes, so the cheapest day to do it is today.

### The argument for not doing it yet

It is a schema migration touching six tables, every DAO query, the backup
format, the PDF statements and the tests. It is three days of work with no
visible benefit to the owner. Doc 14's Supabase port is coming and would have to
carry the same change. And the epsilon **does work today** — there is no known
open bug caused by it, only a known fragility.

### The recommendation

**Do it, and do it before doc 14, but after blocks A–D.** Not first: block A has
to exist before a change this wide is safe, and block C makes the DAO surface
small enough to migrate confidently. Not never: porting a float money model into
Supabase means living with it for another two years.

If the owner would rather not spend the three days, the minimum defensible
alternative is: route `watchShopStats`'s outstanding through the epsilon,
add an `assert` in debug builds that catches any money comparison not using it,
and write down in `AGENTS.md` that money is float and every comparison goes
through `_moneyEquals`. That is an hour and it stops the drift getting worse.

### The work, if approved

1. Schema v7: every `RealColumn` money field becomes `IntColumn` holding paise.
   Migration multiplies by 100 and rounds.
2. `lib/utils/money.dart` gains `Paise` conversions; every display path divides
   at the last moment.
3. `_moneyEpsilon` and `_moneyEquals` are **deleted**, not adapted. If any
   comparison still needs a tolerance, the migration is wrong.
4. Backup format gains a version marker; the reader converts old float backups
   on import.
5. `money_test.dart`, `ledger_test.dart`, `billing_test.dart` and
   `migration_test.dart` all extend. `migration_test.dart` gains a v6→v7 case
   with fractional values that round.

### Done when

`grep -rn 'epsilon' lib/` returns nothing, and a v6 database with a
half-settled bill migrates to v7 and still reads `Partial`.

---

## G · Housekeeping, no block of its own

Small items worth doing whenever the relevant file is open.

- **Money formatting** *(finding 17)*. Five sites bypass
  `lib/utils/money.dart` and break `AGENTS.md` rule 7:
  `record_payment_sheet.dart:112, 126, 152`, `product_form_screen.dart:258`,
  `catalog_share_service.dart:28`. The first two print Western grouping on the
  screen where the owner reads a shop's balance before taking cash. Add a
  `currencySymbol` accessor to the `MoneyFormat` extension so the two
  `prefixText` sites have something correct to use.
- **`didUpdateWidget`** *(finding 19)*. Three widgets seed `State` from
  `widget.*` in `initState` and none override it. All correct today; all latent.
  The app now uses `StatefulShellRoute.indexedStack`, which retains branch
  state, so the ground has already moved. Add the overrides, or lift the state
  into providers — prefer the latter where the state outlives the widget.
- **Save guard in order entry** *(finding 20)*. `if (_saving) return;` plus a
  re-run flag removes the concurrent-`replaceOrderLines` question. Benign today
  because both writers write the same map. Fold into block C.
- **`shop_ledger_screen.dart` is 909 lines** and `order_entry_screen.dart` is
  839. Both hold a screen, its sheets, its rows and its rules in one file, and
  both are where this review's defects concentrate. Split the sheets and rows
  out as block C touches each file. Do not do it as a standalone refactor — a
  900-line move with no behaviour change is unreviewable.
- **Accessibility** is untested ground. Three `Semantics` uses in 19,097 lines
  and no handling of large text scale. Not a finding, because nothing is known
  to be broken. Worth one pass with TalkBack on and the system font at maximum
  before the next release, since the primary user works at 5 a.m. in poor light.
- **Mark the earlier audits superseded.** `app-audit.md` and
  `flutter-lifecycle-audit.md` describe an app that no longer exists in several
  important ways. A reader cannot tell which parts still hold. Add a header line
  to each pointing at `code-review-2026-09.md` §6, which records what closed and
  what did not.
- **Update `AGENTS.md`.** Rule 2's violation count reads 24 across 12 files. It
  is 30 across 14. Rule 18 says to update the file when a rule's facts change.

---

## H · Sequencing, and what to do if there is less time

```
Week 1   A ░░ + B ████████        Everything that loses data or lies to the user
Week 2   C ████████████████       The seam
Week 3   D ████████  E ████████   Discipline and speed
Later    F ████████████████████   Money type, before doc 14
```

**Half a day available:** block A. The suite exists; make it count.

**Two days:** A and B. Every data-loss and user-facing-lie finding is closed.

**A week:** A, B, C. The layering rule stops losing, and doc 14 gets cheap.

**Two weeks:** add D and E. Every finding in the review except the money type is
closed.

Block F is a separate conversation with the owner, because it is three days that
produce nothing they can see. The case for it is in §F. The honest summary is
that it is not urgent and it is not optional — it is the kind of work that is
cheap now and expensive later, and the app's whole job is being right about
money.
