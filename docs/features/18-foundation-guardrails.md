# 18 — Guardrails, AGENTS.md & performance verification

| | |
|---|---|
| **Target version** | `1.10.0+14` — **ships with [10a](10a-design-system.md)** |
| **Type** | Fix (the release takes 10a's minor bump) |
| **Schema** | No change |
| **Requires** | [10a — Design system](10a-design-system.md) committed on the same branch |
| **Followed by** | [10b — Navigation](10b-navigation.md) |
| **Status** | Ready |

## Why

Three loose ends and one live defect, grouped because none of them justifies a release
on its own and all four have to be closed **before** twenty screens get rebuilt.

**1. 10a's performance work is written but not measured.** Four of its success criteria
need a physical device and were left unticked: cold start under 600 ms, an 18-shop list
visible within 200 ms, 60 fps with no `saveLayer` warnings, and one live
`watchOrderSummaries` subscription after visiting fourteen dates. The code behind all
four is in — the pre-blurred background, the shortened stagger, the reworked splash, the
twelve `autoDispose` families. Whether any of it worked is unknown. **Unmeasured
performance work is half-finished performance work**, and [10b](10b-navigation.md) and
[10c](10c-screen-restyle.md) both build on top of it.

**2. The lifecycle audit's guardrails are not in.** Phase 0 of
[`docs/flutter-lifecycle-audit.md`](../flutter-lifecycle-audit.md) is half a day of lint
configuration that makes every later phase enforceable. Landing it after the refactors it
governs is backwards — the point of a ratchet is that it goes in first.

**3. `AGENTS.md` is five lines of style rules.** The project needs a written architecture
before the codebase gets rebuilt, not after. [Doc 13](13-distribution-docs.md) had it
scheduled for later; it moves here.

**4. Order entry silently loses data, today, in production.** `order_entry_screen.dart:104`

```dart
@override
void dispose() {
  _debounce?.cancel();      // ← the pending 500 ms save is thrown away
  super.dispose();
}
```

Any quantity typed in the last 500 ms before leaving the screen never reaches the
database. On the app's busiest screen, at 5 a.m., where ~200 numbers get typed. This is
the one item here that is a defect rather than hygiene, and it is why this release is
typed `fix`.

**Explicitly out of scope:** any screen restyle ([10c](10c-screen-restyle.md)), any
navigation change ([10b](10b-navigation.md)), and the rest of the lifecycle audit's
Phase 2 — the `OrderDraftController` refactor, the `setState`-wrapped DB writes and the
`_init` failure path all wait for 10c, which rebuilds those screens anyway.

## Action items

### Flush the debounce — the defect

- [ ] `lib/screens/order_entry/order_entry_screen.dart` — in `dispose()`, **before**
      `super.dispose()` (where `ref` is still valid), flush instead of discarding:

      ```dart
      @override
      void dispose() {
        if (_debounce?.isActive ?? false) {
          _debounce!.cancel();
          _save();            // fire-and-forget; the DAO outlives this widget
        }
        super.dispose();
      }
      ```

- [ ] Confirm `_confirmOrder` still cancels-then-saves on its own path, so a confirm
      followed by a pop does not write twice.
- [ ] `test/` — pop order entry 100 ms after a quantity change; assert the quantity is in
      the database.

> **This is deliberately the three-line version, not the right one.** The lifecycle audit
> asks for an `OrderDraftController` (`Notifier`) that owns the timer and exposes
> `flush()`, called from `dispose`, from `AppLifecycleState.paused` and from confirm.
> That is the correct shape and it lands in [10c](10c-screen-restyle.md) with the rest of
> Phase 2. Shipping the three-line flush now closes live data loss six weeks earlier;
> the test written here carries over unchanged and keeps the refactor honest.

### Phase 0 — guardrails

Straight from [the audit's Phase 0](../flutter-lifecycle-audit.md#phase-0--guardrails--05-day--no-behaviour-change).

- [ ] `riverpod_lint` + `custom_lint` into `dev_dependencies`, enabled in
      `analysis_options.yaml`.
- [ ] Turn on the rules the audit found violations of:

      ```yaml
      linter:
        rules:
          - use_build_context_synchronously
          - discarded_futures          # catches the setState-wrapped DB writes
          - unawaited_futures
          - avoid_void_async
          - cancel_subscriptions
          - close_sinks
          - always_declare_return_types
      ```

- [ ] Every violation that is not fixed in this release carries an `// ignore:` with a
      reason and a link to the doc that removes it. No bare ignores.
- [ ] `deprecated_member_use_from_same_package: true` stays on. It is 10c's progress bar.
      Record the current count in the PR description — it was **84** when 10a landed.
- [ ] CI runs `flutter analyze` and `flutter test` on every push, and **fails** on either.

### Fix the red migration test first

- [ ] `test/migration_test.dart`, `v4 -> v5 upgrade` — fails today and failed before 10a
      started. Fix it, or delete it with the reason written down.

> CI cannot be made blocking while a test is red. Teaching CI to tolerate one known
> failure is how a suite stops meaning anything — the exception outlives the reason for
> it. With the schema chain now frozen at v6 this is the last migration bug that will
> ever be written, so fixing it once closes the subject.

### The agent docs

Three files, split by what goes stale at what rate. One file mixing all three rots fastest.

- [ ] **`AGENTS.md` — the rules.** Working rules, what the app is, the
      DAO → provider → screen layering rule, and the ten conventions that must not be
      broken. Kept short enough to read in full every session, and it ends in a pointer
      table to everything else.
- [ ] **`docs/architecture.md` — the facts.** Stack, directory map, data model, the
      design-token rules, and the routes.
- [ ] **`docs/development.md` — the procedures.** Setup, seed data, tests, and the release
      steps.
- [ ] `claude.md` keeps the working philosophy — ask don't assume, simplest thing first,
      don't touch unrelated code, flag uncertainty.
- [ ] Each file states when it is updated: **the same commit as the thing it describes.**
      A stale architecture doc is worse than none, because it is believed.
- [ ] Write all three in plain English. Short sentences, one idea each, no jargon. These
      files are read under time pressure, by people and by agents.

### AppErrorView into the kit

- [ ] `lib/widgets/ui/app_error_view.dart` — message, cause, retry callback. Exported
      from `ui.dart`, documented in the kit README, token-clean.
- [ ] Do **not** migrate any screen onto it here. [10c](10c-screen-restyle.md) replaces
      all sixteen `Text('Error: $e')` sites and all twelve error-swallowing `orElse`
      sites in one reviewable pass. This release only puts the component on the shelf,
      the same way 10a shipped the rest of the kit unused.

### Measure 10a — on the owner's device

No code unless a number comes back bad. Record every figure in the PR description so
there is a baseline to regress against.

- [ ] Cold start to first interactive frame. Target **under 600 ms** plus native splash.
- [ ] 18-shop home list fully visible within **200 ms** of data arriving.
- [ ] Scroll the home list with the DevTools performance overlay. 60 fps, and **zero**
      `saveLayer` warnings from the background.
- [ ] Visit 14 consecutive dates on home, return to today, count live
      `watchOrderSummaries` subscriptions. Expect **one**. Count it with a counter in the
      DAO or the Riverpod observer — not by reading the code.
- [ ] Anything that misses its target gets a line in this doc saying by how much, and
      either a fix here or a named owner in [10c](10c-screen-restyle.md). "Close enough"
      is not a result.

## Success criteria

- [ ] A quantity typed and the screen popped 100 ms later is in the database. Covered by
      a test, not by manual checking.
- [ ] `flutter analyze` is clean under the new rules, apart from the `@Deprecated` alias
      warnings, whose count is recorded.
- [ ] `flutter test` is fully green. No skips, no known failures.
- [ ] CI fails a pull request that introduces an analyzer error or a failing test.
      Verified by pushing a deliberate violation once and watching it go red.
- [ ] The three agent docs describe the app as it actually is on the day they land —
      schema v6, the module layout after 10a, the token rule, the release procedure.
- [ ] `AGENTS.md` fits on two screens. If it does not, the overflow belongs in
      `architecture.md` or `development.md`.
- [ ] All four 10a performance numbers exist as numbers in the PR description.
- [ ] `AppErrorView` exists, is exported, and `tool/check_tokens.sh` passes on it.

## Notes

- **Why this has no version of its own.** Alone it is lint config, three docs and one
  invisible bug fix — not a release anybody can be told about. It goes out inside
  [10a](10a-design-system.md)'s release, which takes the minor bump for the visible half.
  See *What a release must be* in the [roadmap](../roadmap.md).
- **Why the guardrails come before 10b and 10c rather than with them.** 10c rewrites
  twenty screens. Turning on `discarded_futures` during that rewrite means the lint
  arrives as noise in a 3,000-line diff. Turning it on now means the rewrite is written
  correctly the first time.
- **Half a day of this release is measurement with no code in it.** That is not padding.
  The four unticked criteria are the reason 10a's performance work currently counts as a
  claim rather than a result.
