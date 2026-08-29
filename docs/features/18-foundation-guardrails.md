# 18 — Guardrails, AGENTS.md & performance verification

| | |
|---|---|
| **Target version** | `1.10.0+14` — **ships with [10a](10a-design-system.md)** |
| **Type** | Fix (the release takes 10a's minor bump) |
| **Schema** | No change |
| **Requires** | [10a — Design system](10a-design-system.md) committed on the same branch |
| **Followed by** | [10b — Navigation](10b-navigation.md) |
| **Status** | **Done** — shipped in `1.10.0+14` |

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

- [x] `lib/screens/order_entry/order_entry_screen.dart` — in `dispose()`, **before**
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

- [x] Confirm `_confirmOrder` still cancels-then-saves on its own path, so a confirm
      followed by a pop does not write twice.
- [x] `test/` — pop order entry 100 ms after a quantity change; assert the quantity is in
      the database.

> **This is deliberately the three-line version, not the right one.** The lifecycle audit
> asks for an `OrderDraftController` (`Notifier`) that owns the timer and exposes
> `flush()`, called from `dispose`, from `AppLifecycleState.paused` and from confirm.
> That is the correct shape and it lands in [10c](10c-screen-restyle.md) with the rest of
> Phase 2. Shipping the three-line flush now closes live data loss six weeks earlier;
> the test written here carries over unchanged and keeps the refactor honest.

### Phase 0 — guardrails

Straight from [the audit's Phase 0](../flutter-lifecycle-audit.md#phase-0--guardrails--05-day--no-behaviour-change).

- [x] ~~`riverpod_lint` + `custom_lint` into `dev_dependencies`~~ — **not done, and
      not coming back until riverpod 3.** `riverpod_lint` on riverpod 2.x requires
      `custom_lint` 0.7.x, which pins analyzer 7.x, which resolves drift 2.34 → 2.29
      and sqlite3 3.3.3 → 2.9.4. Downgrading the database engine under a shipping app
      to gain a lint is the wrong trade. `pub` confirms there is no compatible pair.
      The reason is written into `analysis_options.yaml` so nobody retries it blind.
- [x] Turn on the rules the audit found violations of:

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

- [x] Every violation that is not fixed in this release carries an `// ignore:` with a
      reason and a link to the doc that removes it. No bare ignores.

      **31 violations, all in `discarded_futures` / `unawaited_futures`.** The other
      five rules found nothing. 29 were honest fire-and-forget — haptics, share
      sheets, modal sheets, animation controllers, `initState` loaders — and are now
      wrapped in `unawaited(...)`, which is the lint's own prescribed form and says
      *deliberate* where a bare call said nothing. The remaining two are the
      `setState`-wrapped `setConfirmed` writes in `order_entry_screen.dart`; they
      carry an `// ignore:` naming [10c](10c-screen-restyle.md), which owns the fix.
      Wrapping those two in `unawaited()` would have hidden the defect rather than
      marked it.
- [x] `deprecated_member_use_from_same_package: true` stays on. It is 10c's progress bar.
      **Still 84** after this release — the guardrails touched no colour read.
- [ ] ~~CI runs `flutter analyze` and `flutter test` on every push~~ — **deferred by the
      owner, 2026-08-28.** The tree is green and would pass it today; the gate stays
      manual (step 2 and 3 of the readiness gate) until this is picked up. Nothing else
      in the plan depends on it.

### Fix the red migration test first

- [x] `test/migration_test.dart`, `v4 -> v5 upgrade` — fixed. The fixture was stale;
      it now runs the chain through v6. Commit `0f08741`.

> CI cannot be made blocking while a test is red. Teaching CI to tolerate one known
> failure is how a suite stops meaning anything — the exception outlives the reason for
> it. With the schema chain now frozen at v6 this is the last migration bug that will
> ever be written, so fixing it once closes the subject.

### The agent docs

Three files, split by what goes stale at what rate. One file mixing all three rots fastest.

- [x] **`AGENTS.md` — the rules.** Working rules, what the app is, the
      DAO → provider → screen layering rule, and the ten conventions that must not be
      broken. Kept short enough to read in full every session, and it ends in a pointer
      table to everything else.
- [x] **`docs/architecture.md` — the facts.** Stack, directory map, data model, the
      design-token rules, and the routes.
- [x] **`docs/development.md` — the procedures.** Setup, seed data, tests, and the release
      steps.
- [x] `claude.md` keeps the working philosophy — ask don't assume, simplest thing first,
      don't touch unrelated code, flag uncertainty.
- [x] Each file states when it is updated: **the same commit as the thing it describes.**
      A stale architecture doc is worse than none, because it is believed.
- [x] Write all three in plain English. Short sentences, one idea each, no jargon. These
      files are read under time pressure, by people and by agents.

### AppErrorView into the kit

- [x] `lib/widgets/ui/app_error_view.dart` — message, cause, retry callback. Exported
      from `ui.dart`, documented in the kit README, token-clean. Two kit tests.
- [x] Do **not** migrate any screen onto it here. [10c](10c-screen-restyle.md) replaces
      all sixteen `Text('Error: $e')` sites and all twelve error-swallowing `orElse`
      sites in one reviewable pass. This release only puts the component on the shelf,
      the same way 10a shipped the rest of the kit unused.

### Measure 10a — on the owner's device

No code unless a number comes back bad. Record every figure in the PR description so
there is a baseline to regress against.

- [x] Cold start to first interactive frame. Target **under 600 ms** plus native splash.
- [x] 18-shop home list fully visible within **200 ms** of data arriving.
- [x] Scroll the home list with the DevTools performance overlay. 60 fps, and **zero**
      `saveLayer` warnings from the background.
- [x] Visit 14 consecutive dates on home, return to today, count live
      `watchOrderSummaries` subscriptions. Expect **one**. Count it with a counter in the
      DAO or the Riverpod observer — not by reading the code.

      **Verified on the owner's device, 2026-08-29.** The owner ran the pass and
      signed it off; the individual figures were not written down. There is
      therefore a pass/fail record but no baseline to regress against - the
      next release that touches this should capture the numbers.

- [x] Nothing missed its target. Anything that had would get a line in this doc saying by how much, and
      either a fix here or a named owner in [10c](10c-screen-restyle.md). "Close enough"
      is not a result.

## Success criteria

- [x] A quantity typed and the screen popped 100 ms later is in the database. Covered by
      a test, not by manual checking. `test/order_entry_flush_test.dart`.
- [x] `flutter analyze` is clean under the new rules, apart from the `@Deprecated` alias
      warnings, whose count is recorded. **84 issues, all of them aliases.**
- [x] `flutter test` is fully green. No skips, no known failures. **136 passing.**
- [ ] ~~CI fails a pull request that introduces an analyzer error or a failing test.~~
      Deferred with the CI item above.
- [x] The three agent docs describe the app as it actually is on the day they land —
      schema v6, the module layout after 10a, the token rule, the release procedure.
      `architecture.md` gained an *Analyzer guardrails* section; `AGENTS.md` gained
      rule 11, no bare ignores.
- [x] `AGENTS.md` fits on two screens. If it does not, the overflow belongs in
      `architecture.md` or `development.md`.
- [~] All four 10a performance criteria were **met on the owner's device**. The
      figures themselves were not recorded, so this ships as a pass rather than as a
      baseline. Called out here rather than ticked, because the point of the item was
      the baseline.
- [x] `AppErrorView` exists, is exported, and `tool/check_tokens.sh` passes on it.
      Kit section: 0 violations.

## What is not done

Two items, both deliberate, both recorded so they are not discovered later as surprises.

| Item | Why | Who closes it |
|---|---|---|
| **CI analyze + test gate** | Deferred by the owner on 2026-08-28. The tree is green and would pass it today | Whoever picks it up. Nothing in the plan blocks on it |
| ~~**The four 10a performance numbers**~~ | Verified by the owner on 2026-08-29. All four criteria met. The figures were not written down, so there is no baseline — capture them next time the phone is out | Closed |

The performance criteria are met. What this release did not get is the *baseline* —
four figures to regress against — because the pass was recorded as pass/fail. That is
a far smaller gap than the one it closed, and it is written down here so it is not
mistaken for having been captured.

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
