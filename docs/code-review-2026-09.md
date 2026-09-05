# Code review — Milano Orders

> Written 2026-09-05, against commit `b5618c3` on `release/1.11.0-navigation`.
> Version `1.10.0+14`, schema v6. 122 Dart files, 19,097 lines in `lib/`.
> 27 test files, 6,735 lines, 324 test cases.
>
> Scope: the whole of `lib/`, plus `android/`, the analyzer config, and the
> release workflow. Read as a **defect list**. The work that follows from it is
> in [`improvement-plan-2026-09.md`](improvement-plan-2026-09.md).
>
> **Method, stated honestly.** This is a static read. No Flutter SDK was
> available in the review environment, so `flutter analyze` and `flutter test`
> were **not run**. Nothing below depends on a runtime observation. Where a
> finding needs a runtime confirmation, it says so.

---

## 0. The one-paragraph version

This codebase is well above the average for its size. The data layer is sound,
the migrations are real, the money rules have one home each, and the comments
explain *why* rather than *what* — which is rare and worth protecting. Doc 18
and doc 10a did what they said: the lifecycle defects, the render cost and the
provider leaks from the two earlier audits are genuinely closed, and the token
ratchet has a number that only goes down.

What is left is narrower and sharper than the earlier audits described, and
three of the items are new:

1. **Money is stored as floating point.** Every rupee column is `REAL`. The
   `_moneyEpsilon` constant in `ledger_dao.dart` is not a clever fix — it is the
   symptom. §1.1
2. **Product photos are stored as cache paths.** The picker's temporary path
   goes straight into the database. Android clears that cache. The photos then
   disappear, and the backup silently drops them. §1.2
3. **The two money write paths still have no error handling.** Recording a
   payment and deleting a payment both throw into nothing. This was the sharpest
   item in the 2026-08-27 audit and it is still open. §1.3

Below that: an unguarded backup import (§2.1), a release build that will sign
itself with the debug key (§2.2), a router that crashes on a malformed link
(§1.5), and a layering rule the codebase breaks 30 times (§3.1).

---

## 1. Correctness and data safety

### 1.1 Money is `double`, everywhere · **High**

`lib/database/tables/order_lines.dart:9`, `payments.dart:7`,
`payment_allocations.dart:9`, `shop_prices.dart:8`, `products.dart:9`,
`shops.dart:9`.

Every money column is `RealColumn` — an IEEE-754 double in a SQLite `REAL`.
`0.1 + 0.2` is not `0.3` in that representation, and a ledger is a long chain of
additions and subtractions.

The code already knows. `ledger_dao.dart:7`:

```dart
const _moneyEpsilon = 0.005;
```

That constant, and the seven comparisons routed through it, exist because
`sum(allocations) == orderTotal` can be false by 1e-13. The comment says so.
This is the correct *workaround*, and the tests prove it works today.

The problem is that the workaround has to be applied everywhere, forever, by
every future author. Miss one comparison and a fully-settled bill reads
`Partial` in front of a shop owner. The epsilon also lives only in
`ledger_dao.dart` — `watchShopStats` (`:487`) computes
`openingBalance + totalBilled - totalCollected` with no epsilon at all, so a
shop that has paid to the last paisa can show an outstanding balance of
`0.0000000001`. It is filtered out of `watchOutstandingByShop` by
`> _moneyEpsilon` (`:302`), but it is *not* filtered on the shop's own ledger
screen, which reads `watchShopStats` directly.

The right model for money is an integer count of the smallest unit. Store paise
as `IntColumn`, divide only at the point of display. Comparisons become exact,
`_moneyEpsilon` is deleted rather than maintained, and the class of bug goes
away instead of being managed.

This is a schema migration and a real piece of work. It is listed first because
it gets more expensive with every row the business writes, and because the app's
entire purpose is being right about money.

**Confidence:** high on the analysis. The severity assumes the business keeps
using the ledger; if the ledger were dropped, this would drop to Medium.

### 1.2 Product photos are stored as cache paths, so they vanish · **High**

`lib/screens/settings/products/product_form_screen.dart:85-86`

```dart
final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
if (picked != null && mounted) setState(() => _photoPath = picked.path);
```

Same at `business_info_form_screen.dart:50-51` for the business logo.

`ImagePicker` writes the chosen image into the app's **cache** directory and
returns that path. The path is then written to `products.photoPath` and treated
as permanent. It is not. Android reclaims the cache directory under storage
pressure, and "Clear cache" in Settings empties it on demand. When that happens:

- Every product photo becomes a broken-image icon. The `errorBuilder` at
  `product_qty_row.dart:60` and `product_list_screen.dart:246` hides the failure,
  so it reads as "the photos were never set" rather than as a fault.
- `backup_service.dart:42-51` skips any photo whose file is missing. The backup
  is then written **without** the photos, and the loss becomes permanent on the
  next restore.
- The catalogue PDF (`catalog_share_service.dart:47-49`) silently loses its
  images too.

The fix is small: copy the picked file into
`getApplicationDocumentsDirectory()` under a name you control, store that path,
and delete the old file when the photo is replaced. `importBackup` already does
exactly this for restored images (`backup_service.dart:152-170`) — the pattern
is in the repository, on the read path only.

**Confidence:** high on the mechanism. Whether a given device has actually
cleared the cache yet is unknown; the defect is latent until it fires, and it
fires without warning.

### 1.3 The two money write paths still have no error handling · **High**

`lib/screens/ledger/record_payment_sheet.dart:60-73`

```dart
setState(() => _saving = true);
final amount = double.parse(_amountCtrl.text.trim());
await ref.read(databaseProvider).ledgerDao.recordPayment(...);
if (mounted) Navigator.pop(context);
```

No `try`, no `catch`, no `finally`. If `recordPayment` throws — a locked
database, a constraint failure, a disk-full write — the sheet stays open with
Save permanently disabled and no message. The user cannot tell whether the
payment landed. Their only move is to dismiss the sheet and guess.

`shop_ledger_screen.dart:190-202` is the same shape on delete:

```dart
if (confirmed) {
  await ref.read(databaseProvider).ledgerDao.deletePayment(entry.paymentId!);
}
```

No guard at all. A failed delete leaves the payment in place and says nothing.

This is the exact finding from §4 of `flutter-lifecycle-audit.md`, written
2026-08-27 and still open. The correct pattern is in the same file, forty lines
up: `_exportStatement` (`shop_ledger_screen.dart:131-159`) does
`try` / `catch` into a SnackBar / `finally` behind a `mounted` guard. It needs
copying, not inventing.

Six `try` blocks exist across `lib/screens` and `lib/widgets`, against 30
UI-initiated database calls.

### 1.4 An unknown payment mode crashes the whole ledger · **Medium**

`lib/database/daos/ledger_dao.dart:447`

```dart
paymentMode: PaymentMode.values.byName(row.read<String>('mode')),
```

`payments.mode` is a plain `TextColumn` with no check constraint
(`tables/payments.dart:9`). `byName` throws `ArgumentError` on anything that is
not exactly `cash`, `upi`, `bank` or `cheque`.

Three ways a bad value gets in: a restore from a backup written by a future
build that added a mode; a hand-edited backup file; database corruption. The
throw happens inside the stream `map`, so it does not fail one row — it fails
the whole `watchShopLedger` stream. The shop's ledger screen, its statement
export, and anything else downstream all break, permanently, with no way for the
user to get past it.

Fall back to a known mode and report, rather than throwing. The value is
display-only; it does not affect a single figure.

### 1.5 A malformed link crashes the router · **Medium**

`lib/app.dart:225, 241, 289, 295` all do
`int.parse(state.pathParameters['id']!)` inside a route builder.
`order_entry_screen.dart:85-87` does the same to the `date` query parameter, and
also indexes `p[0]`, `p[1]`, `p[2]` without checking the split produced three
parts.

`/shops/abc/ledger` throws `FormatException` while building the route.
`/order/1?date=yesterday` throws the same way, or `RangeError` on the index.
There is no `errorBuilder` on the `GoRouter`, so the user gets the framework's
red error page.

Today this is only reachable by hand. It stops being theoretical the moment the
app takes an `intent-filter` deep link, which the manifest's `<queries>` block
suggests is on the horizon. `int.tryParse` plus a redirect to the branch root,
and a `GoRouter.errorBuilder`, close it in a few lines.

### 1.6 Order entry's `_init` has no failure path · **Medium**

`lib/screens/order_entry/order_entry_screen.dart:95-144`

`_init` runs a shop read, a `getOrCreateOrder`, and four stream `.first` calls.
There is no `try`. Any throw leaves `_loading` at `true` forever, and the user
gets an infinite spinner on the app's primary data-entry screen, at 5 a.m.

This too is carried over from the 2026-08-27 audit (§3.2) and is still open.
The `AppErrorView` widget that would render the failure already exists
(`lib/widgets/ui/app_error_view.dart`) and is used by the bootstrap gate.

### 1.7 A restore aborts on any orphan outside the two scrubbed tables · **Medium**

`lib/database/daos/backup_dao.dart:96-125`

The restore drops `shopPrices` and `standingOrders` rows whose shop or product
is missing, with a good comment explaining why. It does not do the same for
`dailyOrders` (→ shops), `orderLines` (→ products), `payments` (→ shops), or
`paymentAllocations` (→ payments, dailyOrders).

`_cleanOrphans` in `app_database.dart:104-108` proves orphaned `order_lines`
existed in v4 databases. A backup taken from such a database, restored into a
build with `PRAGMA foreign_keys = ON`, trips SQLITE_CONSTRAINT and rolls the
whole transaction back. The user sees "Restore failed" with a raw exception and
no path forward — and they have just been told their existing data would be
erased.

Apply the same id-set filter to the other four tables.

### 1.8 Two concurrent saves can race in order entry · **Low**

`order_entry_screen.dart:175-193`. `_setQty` schedules `_save` 500 ms out.
`_flushPending` (`:155-159`) cancels the timer and awaits `_save` directly. Both
call `replaceOrderLines`, which is delete-then-insert inside a transaction.

If a flush fires while a debounced save is already in flight — the app is
backgrounded during a save, say — two `replaceOrderLines` transactions run
against the same order. Drift serialises them, so the database stays consistent,
and both write the same `_qtys` map, so the outcome is the same either way.

It is a Low because the current data flow makes it benign, not because the shape
is safe. A save guard (`if (_saving) return;` plus a re-run flag) removes the
question.

### 1.9 The dashboard settings toggle can silently not persist · **Low**

`lib/providers/dashboard_settings_provider.dart:25-55`

```dart
DashboardSettingsNotifier() : super(const DashboardSettings()) {
  unawaited(_load());
}
...
state = updated;
await _prefs?.setBool(key, value);   // null-safe: silently no-ops
```

Two defects, both from the 2026-08-27 audit (§5.3), both still open. The
notifier publishes a default state before `SharedPreferences` resolves, so every
section switch renders ON and then flips to its real value. And a toggle hit
before `_load()` completes finds `_prefs` null, the `?.` swallows the write, the
UI updates, and the setting is not saved.

The window is short and the setting is cosmetic, which is the only reason this is
Low. `AsyncNotifier` makes both states unrepresentable.

---

## 2. Security

The app is single-user, offline, and holds no credentials. That correctly limits
the attack surface. Three things still matter.

### 2.1 Path traversal in backup import · **Medium**

`lib/services/backup_service.dart:161-169`

```dart
final imageKey = _findImageKey(images, 'product_${product['id']}.');
...
final outFile = File(p.join(imagesDir.path, imageKey));
await outFile.writeAsBytes(bytes);
```

`imageKey` is a **key from the imported JSON file**. `_findImageKey` (`:108-113`)
only checks the prefix; the rest is attacker-controlled. A key of
`product_1./../../../databases/milano_orders.db` passes the prefix test, and
`p.join` happily resolves the `..` segments out of `imported_photos`.

The blast radius is the app's own sandbox, so this is not a device compromise.
Inside that sandbox it is enough to overwrite the database file, the shared
preferences, or anything else the app owns — with content the attacker chose,
during an operation the user has just been told will erase their data anyway.

The delivery path is realistic for this app: backups are the *documented* way to
move data between devices, they arrive as files over WhatsApp or email, and the
user is trained to import them.

Fix: reject any key that is not a plain filename. `p.basename(imageKey)` plus a
check that the result still matches the expected pattern is two lines.

Same shape at `:175-180` for `logo.`.

### 2.2 A release build silently falls back to the debug signing key · **Medium**

`android/app/build.gradle.kts:52-58`

```kotlin
signingConfig = if (keystorePropertiesFile.exists()) {
    signingConfigs.getByName("release")
} else {
    signingConfigs.getByName("debug")
}
```

The comment explains the intent — `flutter build apk --release` should work
without a local keystore. That is a real convenience. The cost is that a release
APK built on any machine without `key.properties` is signed with the Android
debug key, whose private key ships with the SDK and is identical on every
developer machine on earth.

The app distributes updates through GitHub Releases and installs them by
sideload. An APK signed with the debug key can be replaced by *anyone*, because
anyone can produce a validly-signed upgrade for it. If such a build ever reaches
a phone, that phone is permanently in that state — Android will not let it
upgrade back to a properly-signed APK.

The CI workflow does write `key.properties` before building
(`release.yml:70-77`), so releases published today are correctly signed. The
risk is a build produced any other way. Fail the release build loudly instead of
falling back, and keep the debug fallback for `debug`/`profile` only.

### 2.3 The update URL is used without checking where it points · **Low**

`update_service.dart:75` reads `browser_download_url` out of the GitHub API
response. `settings_screen.dart:411-414` hands it straight to `launchUrl` with
`LaunchMode.externalApplication`.

The response arrives over HTTPS from `api.github.com`, so the value is as
trustworthy as the repository. But nothing in the app constrains it. A
compromised or mistyped release asset can point the user's browser anywhere, on
a flow whose next step is "install this APK".

Two cheap checks: require `https`, and require the host to be a GitHub domain.
Refuse the update otherwise.

### 2.4 Noted, not defects

- **The database is unencrypted.** `milano_orders.db` sits in app-private
  storage in plaintext, holding every shop's name, phone, balance and payment
  history. On a non-rooted device with a screen lock this is adequately
  protected by the platform. `android:allowBackup="false"` is set, which
  correctly keeps it out of Google's cloud backup. Worth a decision, not a fix:
  SQLCipher is the option if the owner's threat model includes a lost, unlocked
  phone.
- **Backups are plaintext JSON**, shared through the OS share sheet, and written
  to the temp directory where they stay until the next export sweeps them
  (`backup_service.dart:79-88`). This is inherent to the feature. It is worth
  stating in the UI that the file contains everything.
- **Permissions are minimal and correct.** `INTERNET`, `VIBRATE`,
  `READ_MEDIA_IMAGES`. Nothing unnecessary.
- **No SQL injection anywhere.** Every `customSelect` uses bound variables. The
  raw SQL in `_cleanOrphans` and `_createIndexes` is static.
- **Release notes from GitHub are rendered as plain `Text`.** No markup, no
  injection surface.

---

## 3. Architecture and code quality

### 3.1 The layering rule is broken 30 times, and the count is rising · **High**

`AGENTS.md` rule 2: *"Never call `databaseProvider` from a screen or a widget."*
`AGENTS.md` names 24 violations across 12 files as a known defect.

Today it is **30 sites across 14 files**. The rule is being broken faster than it
is being closed:

| Audit | Date | Sites | Files |
|---|---|---:|---:|
| `flutter-lifecycle-audit.md` §5.4 | 2026-08-27 | 23 | 12 |
| `AGENTS.md` | 2026-08-30 | 24 | 12 |
| This review | 2026-09-05 | **30** | **14** |

The read path is clean — providers wrap the DAO `watch*` queries and screens read
`AsyncValue`. It is the writes. Every form, every delete, every payment goes
`ref.read(databaseProvider).someDao.someMethod(...)` from inside a gesture
handler.

Three costs, in order of how soon they land:

1. The DAOs are `part of` the generated database, so they cannot be mocked. Any
   test of a write path has to stand up a real `AppDatabase.forTesting`.
2. Error handling has no shared home, which is precisely why §1.3 is still open —
   there is no one place to put the `try`.
3. Doc 14's Supabase port replaces the thing 14 files reach into directly.

`docs/features/14a-repository-seam.md` already owns this. The number in it is
out of date.

**This is the finding that should be acted on first**, ahead of the money-type
migration, because it is the one that makes the others cheap.

### 3.2 Errors still render as empty states · **Medium**

19 `maybeWhen(..., orElse:)` sites in `lib/screens`, up from 12 at the last
audit. Four are in one build method:

`lib/screens/kitchen/kitchen_screen.dart:45-60` maps loading *and* error to empty
collections for shops, products, categories and lines. The screen then renders
"No orders for this date."

**A database failure tells the baker there is nothing to bake.** That is the
same defect the 2026-08-27 audit named, in the same file, at nearly the same
lines. `orders_screen.dart:39-51` does it three times, including for
`billDuesForDateProvider` — so a failure to load payment status renders every
bill as unpaid.

`AppErrorView` exists and is good. It is used by the bootstrap gate and almost
nowhere else.

### 3.3 The dashboard's freshness is still hand-maintained · **Medium**

`dashboard_screen.dart:196-209` invalidates **14 providers** by hand, in a list a
human has to remember to extend. Twelve `FutureProvider`s in
`dashboard_provider.dart` are one-shot reads over a database the rest of the app
watches reactively.

Add a fifteenth dashboard provider, forget the line, and it silently never
refreshes. No test and no analyzer rule can catch the omission.

Everything else in the app is a `StreamProvider` over a Drift `watch*` and is
correct by construction. The dashboard opted out and rebuilt a weaker version by
hand. `dashboard_dao.dart` needs `watch` variants; the shapes are already right.

### 3.4 Money formatting bypassed in five places · **Medium**

`AGENTS.md` rule 7: *"Format all money with `lib/utils/money.dart`. Never write
`₹` or a `NumberFormat` pattern."*

| File | Line | What it writes |
|---|---:|---|
| `record_payment_sheet.dart` | 112 | `'₹${pinned.amountDue.toStringAsFixed(2)}'` |
| `record_payment_sheet.dart` | 126 | `'Outstanding ₹${outstanding.toStringAsFixed(2)}'` |
| `record_payment_sheet.dart` | 152 | `prefixText: '₹ '` |
| `product_form_screen.dart` | 258 | `prefixText: '₹ '` |
| `catalog_share_service.dart` | 28 | `'₹$text / ${product.unit}'` |

The first two are the ones that matter: `toStringAsFixed` is Western grouping, so
a balance of 116717 prints as `116717.00` where the rest of the app prints
`1,16,717.00`. The record-payment sheet is where the owner reads a shop's
outstanding balance before taking cash for it.

The two `prefixText` sites are a genuine gap in the `MoneyFormat` extension —
there is no accessor for the bare symbol. Add one.

`catalog_share_service.dart:28` is a customer-facing PDF, and it hardcodes the
symbol that doc 17's white-labelling exists to make configurable.

### 3.5 `didUpdateWidget` is still absent everywhere · **Low**

Zero overrides in 122 files, against three widgets that seed `State` from
`widget.*` in `initState`: `order_entry_screen.dart:85`,
`product_qty_row.dart`, and the ledger filter sheet.

All three are correct today because each is entered fresh. Each becomes a
silent stale-data bug the first time its widget is rebuilt in place — a route
parameter change, a list reorder, a retained shell branch. The app now uses
`StatefulShellRoute.indexedStack`, which retains branch state, so the ground has
already shifted under this.

### 3.6 Structural notes

- **`shop_ledger_screen.dart` is 909 lines** and `order_entry_screen.dart` is
  839. Both hold a screen, its sheets, its rows and its business rules in one
  file. Both are the files where the defects above concentrate. That is not a
  coincidence.
- **No `lib/repositories/`**, per §3.1.
- **`selectedDateProvider` is still a `StateProvider`** (`date_provider.dart:60`)
  while `todayProvider` beside it was correctly modernised to a `Notifier`. Two
  idioms, one file.
- **The `@Deprecated` colour aliases work as designed.** 289 token violations
  remain by `tool/check_tokens.sh`, down from 396, with the kit itself clean.
  The ratchet is doing its job.

---

## 4. Performance

The two audits' headline performance findings are **fixed**, and fixed properly.
See §6. What is left:

### 4.1 The order-entry list decodes full-resolution photos · **Medium**

`lib/widgets/product_qty_row.dart:57-62`

```dart
child: Image.file(
  File(product.photoPath!),
  fit: BoxFit.cover,
  errorBuilder: ...,
),
```

Drawn into a 48×48 box. No `cacheWidth`, no `cacheHeight`.

A gallery photo from a modern phone is 12 megapixels. Decoded to a raw bitmap
that is roughly 48 MB, per photo, held in the image cache, to be drawn at 48×48.
With 28 products this is the single largest memory cost in the app and it lands
on the scrolling thread.

`product_list_screen.dart:236-245` already fixed exactly this, and left a comment
saying why:

> *"Product photos come from the camera. Without this the full multi-megapixel
> image was decoded to be drawn at 40x40, on the scrolling thread — a large part
> of why these lists stuttered."*

The fix was applied to the product list and the share picker. It was not applied
to order entry, which is the screen the owner uses every morning. Two lines.

Same gap, less hot: `product_form_screen.dart:204` (100×100) and
`business_info_form_screen.dart:119`.

### 4.2 Order entry writes 28 rows every 500 ms · **Medium**

`order_dao.dart:69-78`. `replaceOrderLines` deletes every line for the order,
then inserts the non-zero ones **one statement at a time** in a loop.

`_setQty` schedules this 500 ms after the last tap. A morning's order entry for
one shop is dozens of taps, so this runs dozens of times, each doing one delete
and up to 28 individual inserts.

Drift's `batch()` sends these as one round trip. `upsertOrderWithLines`
(`:54-67`) has the same shape.

A cheaper fix on top: only write the lines that changed. The debounce already
knows which product ids moved.

### 4.3 Backup export and restore are unbatched and fully in memory · **Medium**

`backup_dao.dart:126-143` inserts `dailyOrders`, `orderLines` and
`paymentAllocations` row by row. A year of trading for 18 shops is roughly 6,500
order lines — 6,500 sequential awaited inserts inside one transaction.

`backup_service.dart:34-96` reads every table, every product photo and the logo
into memory, base64-encodes the images, and builds one JSON string. The
`compute` call copies the whole structure across an isolate boundary. Peak memory
is roughly three times the size of the photo set. With 28 product photos at
4 MB each that is a plausible out-of-memory on a low-end device.

`batch()` fixes the restore. Streaming the JSON, or storing photos beside the
backup rather than inside it, fixes the export.

### 4.4 `watchOutstandingByShop` is a correlated subquery per shop · **Low**

`ledger_dao.dart:267-304`. For every shop, three correlated subqueries, one of
which contains two more. It watches five tables, so it re-runs on **every** order
line write — which means it re-runs on every 500 ms order-entry save, for every
shop, while the owner is typing.

At 18 shops this is fine. It is listed because the drawer's outstanding card
keeps it permanently subscribed, so the cost is paid continuously rather than
when someone looks at receivables.

### 4.5 Eleven eager `ListView(` against twenty `ListView.builder`

Down from the earlier audit's 6-against-4 and now the right way round. The
remaining eager ones are settings pages with fixed short content, which is the
correct use. No action.

---

## 5. Testing, tooling and process

### 5.1 Nothing runs the tests · **High**

`.github/workflows/release.yml` is the only workflow. It builds and publishes an
APK on every push to `master` that bumps the version. It does not run
`flutter analyze`. It does not run `flutter test`.

There are **324 test cases across 6,735 lines**, concentrated exactly where they
should be — money, migrations, routing, lifecycle. That is a genuinely good
suite. Nothing enforces it. A commit that breaks every test in the repository
ships to the owner's phone.

The analyzer situation is the same. `analysis_options.yaml` enables seven
guardrail lints from doc 18 — `discarded_futures`, `unawaited_futures`,
`use_build_context_synchronously` and four more — and a
`deprecated_member_use_from_same_package` rule that exists specifically to be a
progress bar. Nothing reads that progress bar in CI.

`tool/check_tokens.sh` is written to run in CI and says so in its own header. It
is not wired to anything.

One `flutter analyze && flutter test && tool/check_tokens.sh` job, required on
pull requests, is the highest value-per-hour change in this document.

### 5.2 Release notes are built from commit subjects unsafely · **Low**

`release.yml:96-105` writes `git log --pretty=format:"- %s"` into a heredoc
delimited by `NOTES_EOF`. A commit whose subject line is `NOTES_EOF` terminates
the output block early and the rest of the log leaks into the workflow's
environment as arbitrary `key=value` pairs.

It needs a malicious or unlucky commit subject to trigger, and the repository has
one author. Use a random delimiter, which is the documented pattern.

### 5.3 What the tests do not cover

Reading the suite against the findings above:

- No test asserts that a failed database write surfaces to the user. §1.3 would
  not be caught.
- No test covers backup import of a hostile or malformed file. §2.1 and §1.7
  would not be caught.
- No test covers a malformed route parameter. §1.5 would not be caught.
- `migration_test.dart` and `backup_test.dart` are good and cover the happy path
  well.

---

## 6. Verified against the earlier audits

The task asked whether the two existing audits are still accurate. They are
substantially **out of date, in the codebase's favour**. Doc 18 and doc 10a did
real work.

### `app-audit.md` (2026-08-26, v1.7.0)

| # | Finding | Status now |
|---|---|---|
| 1 | No design tokens; 14 font sizes, 111 greys, 8 radii | **Partly closed.** `lib/theme/tokens.dart` exists, the kit in `lib/widgets/ui/` is clean, and `check_tokens.sh` reports 289 remaining screen violations against a 396 baseline. Working as designed |
| 2 | 68% of routes behind "Profile" | **Closed.** Five shell branches, a drawer, `/settings/*`, and `legacyRedirectFor` keeps old links alive |
| 3 | Blurred PNG repainting under every screen | **Closed.** `app_background.dart` bakes the blur into the asset, adds a `RepaintBoundary` and caps the decode at 360px |
| 4 | 0 of 35 providers `autoDispose` | **Closed.** Every family provider is `autoDispose`; `read_once.dart` documents which are deliberately not, and why |
| 5 | Ledger four taps deep; outstanding unreachable | **Closed.** `/outstanding` exists, the drawer carries the headline figure |
| 6 | Two competing header idioms | **Closed.** `AppScaffold` is used across the shell screens |
| 7 | 360 ms stagger, 1.2 s splash gate | **Closed.** `ListFadeIn` wraps the list not the row; the splash route is deleted and `legacyRedirectFor` redirects `/splash` |
| 8 | Order entry rebuilds 28 rows per tap | **Open**, and now with §4.1 on top of it |
| 9 | Colour carries no meaning | **Closed.** Semantic tokens exist in `tokens.dart` |
| 10 | Low-density lists, inert empty states | **Closed.** `EmptyState`, `StatBand`, `ListRow`, `HeroStatCard` all shipped |
| 11 | "Milano" hardcoded in the UI | **Closed.** Zero UI-string matches; `BrandConfig` resolves it |
| 12 | Dead `/dashboard` in `_topLevelPaths`; 14 hand invalidations | **Half closed.** The dead entry is gone. The 14 invalidations are still there — §3.3 |

### `flutter-lifecycle-audit.md` (2026-08-27, v1.9.1)

The three defects named in its §0:

| Defect | Status now |
|---|---|
| Order quantities typed in the last 500 ms are discarded | **Closed.** `_flushPending` on `dispose`, plus `PendingWrites` flushed from `AppLifecycleScope.onPause` |
| A DB failure on Kitchen renders as "No orders for this date" | **Open.** `kitchen_screen.dart:45-60` — §3.2 |
| An app left open overnight reports yesterday as today | **Closed, well.** `TodayNotifier` carries a midnight timer, `AppLifecycleScope` handles resume, and `package:clock` makes it testable |

Its migration phases:

| Phase | Status |
|---|---|
| 0 — Guardrails | **Done.** Seven lints enabled, with a written reason for excluding `riverpod_lint`. Not enforced in CI — §5.1 |
| 1 — Application lifecycle | **Done, and done properly.** `ProviderScope` owns the container, bootstrap runs in the tree behind a gate, the splash comes down on a post-frame callback, one `AppLifecycleListener`, `FlutterError.onError` + `PlatformDispatcher.onError` + `ProviderObserver` all installed |
| 2 — Close the three defects | **Two of five items done.** The debounce flush is closed. `_init`'s failure path (§1.6), `record_payment_sheet` (§1.3) and the sweep of the remaining UI calls are open. The `setState` writes are still there, now with `// ignore: discarded_futures` and a note naming doc 10c — which is the honest way to carry a known defect |
| 3 — `AsyncValue` discipline | **Not started.** 19 `orElse` sites, up from 12. `AppErrorView` was built but not adopted |
| 4 — Riverpod modernisation | **Partly.** `todayProvider` and `bootstrapProvider` are modern. `dashboardRangeProvider` and `dashboardSettingsProvider` are still `StateNotifier`; `selectedDateProvider` is still a `StateProvider`. The dashboard `FutureProvider`s are unchanged |
| 5 — Widget lifecycle & data seam | **Not started.** No `lib/repositories/`, no `didUpdateWidget`, `databaseProvider` reachable from 14 screen files |
| 6 — Theme and router from the tree | **Mostly done.** `routerProvider` exists and is overridable; `buildAppTheme(brand)` is extracted; the deprecated colour aliases are the tracked remainder |

**Recommendation:** both documents should be marked superseded by this one rather
than left as current-state records. They describe an app that no longer exists in
several important ways, and a reader cannot tell which parts still hold.

---

## 7. What is right, and should not be "improved"

Stated so that the plan does not break it.

- **The comments.** They explain the decision and name the alternative that was
  rejected. `read_once.dart`, `order_entry_screen.dart:437-447` on why
  `categoriesProvider` is a one-shot read, `app_background.dart` on what the
  blur used to cost. This is the most valuable thing in the repository and it is
  rare. Protect it.
- **The lifecycle work.** `AppLifecycleScope`, `PendingWrites`, `TodayNotifier`,
  `AppBootstrapGate`. All four are correct, minimal, and solve a real problem
  each. `TodayNotifier`'s belt-and-braces timer plus resume hook is exactly right.
- **The ledger's money rules.** One epsilon, one `_billStatusFor`, one
  `_allocate` that every allocation path goes through, one `ledgerEntryInRange`
  shared by the screen and the PDF so they cannot disagree. The reasoning about
  zero-total orders and opening-balance cutoffs is careful and consistent across
  six queries. §1.1 is about the storage type, not about this logic.
- **The migration chain.** Real, incremental, with orphan cleanup before the FK
  pragma turns on, and indexes created with a documented rationale for choosing
  single-column over composite.
- **The token ratchet.** A script that can only go down, blocking on the kit from
  day one and reporting on the screens. That is the right shape for this problem.
- **`legacyRedirectFor`.** Pure, tested as itself, one prefix rule covering paths
  the file never enumerates, with a note saying when it can be deleted.
- **The test suite's placement.** 324 cases, concentrated on money, migrations
  and routing. The right things are tested. They just are not run.

---

## 8. Findings, ranked

| # | Finding | Severity | § |
|---|---|---|---|
| 1 | Nothing runs `analyze` or `test` in CI | **High** | 5.1 |
| 2 | `databaseProvider` reached from 14 screen files, 30 sites, rising | **High** | 3.1 |
| 3 | Money stored as floating point | **High** | 1.1 |
| 4 | Product photos stored as cache paths — they disappear | **High** | 1.2 |
| 5 | Payment record and delete have no error handling | **High** | 1.3 |
| 6 | Path traversal in backup import | Medium | 2.1 |
| 7 | Release build falls back to the debug signing key | Medium | 2.2 |
| 8 | Errors render as empty states — "nothing to bake" | Medium | 3.2 |
| 9 | Unknown payment mode crashes the ledger stream | Medium | 1.4 |
| 10 | Malformed route parameter crashes the router | Medium | 1.5 |
| 11 | Order entry's `_init` has no failure path | Medium | 1.6 |
| 12 | Restore aborts on orphans outside the two scrubbed tables | Medium | 1.7 |
| 13 | Order-entry photos decoded at full resolution | Medium | 4.1 |
| 14 | Order lines written one statement at a time | Medium | 4.2 |
| 15 | Backup export/restore unbatched and fully in memory | Medium | 4.3 |
| 16 | Dashboard freshness hand-maintained across 14 invalidations | Medium | 3.3 |
| 17 | Money formatting bypassed in five places | Medium | 3.4 |
| 18 | Update URL used without host or scheme check | Low | 2.3 |
| 19 | `didUpdateWidget` absent; three latent stale-state widgets | Low | 3.5 |
| 20 | Concurrent-save race in order entry | Low | 1.8 |
| 21 | Dashboard settings toggle can silently not persist | Low | 1.9 |
| 22 | `watchOutstandingByShop` re-runs on every order write | Low | 4.4 |
| 23 | Release-notes heredoc delimiter is guessable | Low | 5.2 |

Nine of these are carried over from the two earlier audits. Fourteen are new.
None of them are in the migration chain or the FIFO allocation logic.
