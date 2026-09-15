# 14a — Repository seam

| | |
|---|---|
| **Target version** | `1.13.1+18` — **ships with [13](13-distribution-docs.md)** |
| **Type** | Fix (patch — refactor, no new capability) |
| **Schema** | No change |
| **Requires** | [10c — Screen restyle](10c-screen-restyle.md) |
| **Followed by** | [14 — Supabase, auth & biometric unlock](14-supabase-auth.md) |
| **Status** | Ready |

## Why

[Doc 14](14-supabase-auth.md) carries one success criterion that decides whether the
Supabase port is a two-week job or a two-month one:

> **No screen file changed as part of the DAO port.**

That is impossible today. Thirteen screen files call `ref.read(databaseProvider)`
**23 times**, reaching past every provider straight into Drift:

```
record_payment_sheet · shop_ledger_screen · order_entry_screen · backup_restore_screen
business_info_form_screen · category_list_screen · price_matrix_screen
product_form_screen · product_list_screen · shop_form_screen · shop_list_screen
standing_orders_screen · splash_screen
```

Every one of those is a screen that changes the day Drift goes. Twenty-three edits
scattered across thirteen files, made during the same release that swaps the storage
engine and adds authentication — that release has no safe rollback and no reviewable
diff. **The read path is already clean**: providers wrap the `watch*` queries and screens
consume `AsyncValue`. It is the write path that leaks, because writes were never given a
home and each screen reached for the nearest handle.

This release gives them one. It is half a day of mechanical work bought as insurance
against the riskiest release in the plan, and it also picks up the rest of
[the lifecycle audit's Phase 5](../flutter-lifecycle-audit.md#phase-5--widget-lifecycle--data-seam--2-days--fixes-3537-54)
while the same files are open.

**Explicitly out of scope:** any behaviour change, any new query, anything Supabase.
Drift stays exactly where it is. If a number on a screen changes, that is a bug.

## What a repository is here

Not an abstraction layer, and not an interface with one implementation. One plain class
per aggregate, holding an `AppDatabase`, exposing **intent-shaped methods** — the
vocabulary the screens already speak, rather than the DAO's:

```dart
class OrderRepository {
  OrderRepository(this._db);
  final AppDatabase _db;

  Future<void> saveLines(int orderId, List<OrderLinesCompanion> lines) => ...
  Future<void> setConfirmed(int orderId, bool value) => ...
}
```

Providers depend on repositories. Screens depend on providers. `databaseProvider`
becomes unreachable from `lib/screens` and `lib/widgets`.

That is the whole design. There is no base class, no generic `Repository<T>`, no
interface — doc 14 replaces the body of each method and nothing else. **A second
implementation is not needed to make the seam useful**; a single call site per operation
is.

## Action items

### The seam

- [ ] `lib/repositories/` — one file per aggregate, matching the DAOs that exist:
      `order_repository.dart` · `shop_repository.dart` · `product_repository.dart` ·
      `price_repository.dart` · `ledger_repository.dart` · `category_repository.dart` ·
      `business_info_repository.dart` · `backup_repository.dart`.
- [ ] One `Provider` per repository, each reading `databaseProvider`. These are the
      **only** remaining readers of it outside `lib/providers/`.
- [ ] Move each of the 23 UI call sites onto a repository method. Where two screens do the
      same write slightly differently, they get one method and the difference is settled
      here — that consolidation is most of the value.
- [ ] `dashboard_dao` and the read path stay as they are. Existing providers keep their
      signatures. **If a provider signature changes, the refactor has gone wider than it
      should.**

### Phase 5 leftovers, while the files are open

- [ ] **`didUpdateWidget`** on the three `initState`-seeding widgets — or better, remove
      the need. Lift state into a provider where it outlives the widget (order entry's
      `_date`); add `didUpdateWidget` where it does not (the filter sheet). There are
      currently **zero** `didUpdateWidget` overrides in the codebase and every
      `widget.*` → `State` seed is a latent staleness bug.
- [ ] **`StatefulWidget` → `ConsumerWidget`** where the only state is a `TabController`
      (Kitchen, Shop Ledger) or a selection `int` (Orders). `TabController` moves to
      `DefaultTabController`; the selection moves to a scoped provider.
- [ ] **`StaggeredFadeIn`** takes a cancellable `Timer` field, cancelled in `dispose` —
      matching the pattern already correct in `product_qty_row.dart:322-341`.
- [ ] Standardise on `context.mounted` after any `await` followed by a `context` use.
      `State.mounted` is for `setState` only.

## Success criteria

- [ ] `grep -rn 'databaseProvider' lib/screens lib/widgets` returns **zero** results.
- [ ] No provider signature changed. Verified by diffing the public API of
      `lib/providers/`, not by inspection.
- [ ] `flutter test` passes with no test modified. The existing suite overrides providers,
      so a correct refactor is invisible to it — **any test that needs editing is a
      signal the seam moved something it should not have.**
- [ ] `flutter analyze` clean under [18](18-foundation-guardrails.md)'s rules.
- [ ] Every screen behaves identically. This is a refactor; a visible change is a bug.
- [ ] A repository method can be swapped for a stub in a test without standing up a
      database. Prove it once, in one test, for one method.

## Notes

- **Why this is not folded into [10c](10c-screen-restyle.md).** 10c already rewrites
  twenty screens' layout. Adding a data-layer refactor to that diff means a reviewer
  cannot tell a restyle regression from a plumbing regression. Separate releases, separate
  blast radii.
- **Why this is not deferred into [14](14-supabase-auth.md).** Doing it inside the port
  means the same commit changes the storage engine, the auth model *and* thirteen screen
  files. The point of the seam is to have already paid that cost when the risky release
  starts.
- **This is the last release before `2.0.0`,** and it ships with
  [13](13-distribution-docs.md) because neither is visible on its own. `1.13.1+18` is the
  version the owner runs while the Supabase work happens on a branch, and the one to fall
  back to if the port stalls. It must be fully stable.
