# Milano Orders — Roadmap

> Last updated: 2026-08-29
> Current shipped version: **1.10.0+14** · schema v6
> **Scope revised 2026-08-28.** See *What changed and why* below before reading anything else.

This is the index. Every feature has its own self-contained plan in `docs/features/`,
sized to ship as **one release**. Build one, bump `pubspec.yaml`, push to `master`,
let CI cut the release, move to the next.

Superseded plans (v1–v5 roadmaps, the original PRD, the release planner) live in
`docs/archive/`. They are history — read them for rationale, never for current scope.

Two current-state records feed this plan:

- [`docs/app-audit.md`](app-audit.md) — structure, visual design, perceived performance.
  The [10](features/10-ui-overhaul.md) block is built from it.
- [`docs/flutter-lifecycle-audit.md`](flutter-lifecycle-audit.md) — framework-level
  correctness: app lifecycle, widget lifecycle, async safety, Riverpod architecture.
  Its six phases are distributed across the releases below rather than shipping as a
  block of their own.

Three files carry the working knowledge. [`AGENTS.md`](../AGENTS.md) holds the rules and
is the file to read first. [`docs/architecture.md`](architecture.md) holds the facts — the
stack, the data model, the routes and the design system.
[`docs/development.md`](development.md) holds the procedures — setup, tests and release.
All three are updated in the same commit as any change they describe.

---

## What changed and why — 2026-08-28

Four decisions, taken by the owner, that reshape everything below.

| Decision | Effect |
|---|---|
| **No stock counting.** This app is production, supply, billing and collection. It does not count inventory | [11 — Counter stock](features/11-counter-stock.md) is **dropped**. The Drift schema chain freezes at **v6** — no v7, no v8, ever. [12](features/12-dashboard-tabs.md), [16](features/16-weekly-ai-report.md) and [17](features/17-white-label.md) lose their stock sections |
| **The UI revamp goes in before any feature work**, and the performance fixes inside it get finished rather than left half-measured | [10a](features/10a-design-system.md) ships as built; the four device-measured criteria it left unticked become a named release, not a footnote |
| **The lifecycle and performance audit moves up**, and the project gets written down so later work is structured | New release [18](features/18-foundation-guardrails.md) lands the lint guardrails now, plus three agent docs: `AGENTS.md` (rules), [`architecture.md`](architecture.md) (facts), [`development.md`](development.md) (procedures). The remaining audit phases fold into the releases that already touch the same files |
| **Supabase for data and storage. Supabase Auth, with public signup disabled. One user, no roles. Biometric unlock on top** | [14](features/14-supabase-auth.md) loses the three-tier role matrix and the per-role RLS table entirely. [16](features/16-weekly-ai-report.md) and [17](features/17-white-label.md) lose their role gating |

Also settled: **white-label comes after Supabase**, unchanged from before.

### What was dropped

| Doc | Status | Why |
|---|---|---|
| [06 — Ledger manual allocation](features/06-ledger-manual-allocation.md) | Deferred | FIFO auto-allocation covers the real cases. Reopen if it bites |
| [09 — Exclude shops from grand total](features/09-shop-exclusion.md) | Dropped | Owner's call, 2026-08-27. Not wanted |
| [11 — Counter stock](features/11-counter-stock.md) | **Dropped** | Owner's call, 2026-08-28. Out of scope for this product |

Their docs stay in place as the record of what was considered and declined. Do not
resurrect one without a fresh decision written into this table.

---

## Branching

**`master` is production.** It only receives finished, verified releases.

- Never commit to `master` directly.
- One branch per release: `release/1.10.0-design-system`, `release/1.11.0-navigation`.
- Merge to `master` only when the readiness gate below passes.
- The merge **is** the release — CI reacts to the version change on `master`.

Do not open a single long-lived branch for the whole plan. It accumulates into one
unreviewable merge, which is the thing this policy exists to avoid.

Commits are cheap. Releases are the meaningful unit. Commit to the branch as often as you
like; bump the version once, at the end.

## What a release must be

**Every release leaves the app fully usable.** No release ships a half-migrated state —
half the screens restyled, half the routes moved, half the providers ported. If the work
cannot land whole, it is not one release.

**Every release can be described in one sentence the owner cares about.** If the only
honest sentence is "internal cleanup", the release is too thin — merge it into the one
before or after. Two of the nine releases below are grouped for exactly this reason.

## The readiness gate

Run this before every merge to `master`. All eight, no exceptions.

1. Every **Success criterion** in the feature doc is ticked.
2. `flutter test` — green. Zero failures, zero skips.
3. `flutter analyze` — clean.
4. `./tool/check_tokens.sh` — passes.
5. The APK is installed on the real phone.
6. The smoke pass is done on that phone: order entry → kitchen → billing → ledger →
   record a payment → export a statement.
7. A backup exported from the **previous** version restores into this one.
8. `version:` in `pubspec.yaml` is bumped.

Step 7 is the one that gets skipped and the one that corrupts real data. Do it.

## Versioning rules

| Change | Bump | Example |
|---|---|---|
| Anything the user can see or feel | **minor** | `1.9.2` → `1.10.0` |
| Invisible fix, refactor, or tooling | **patch** | `1.13.0` → `1.13.1` |
| Supabase / auth | **major** | `1.x` → `2.0.0` |

- **A restyle is a minor bump.** The old rule called it a patch, because it adds no new
  capability. That was wrong from the phone: the owner opens a different-looking app, and
  the version number should say so. Revised 2026-08-28.
- Build number (`+N`) increments by **one on every release**, without exception.
  It never resets and never skips.
- A release containing both a feature and fixes takes the **minor** bump — the
  highest-order change in the release decides.
- `2.0.0` is reserved. Nothing reaches it before the Supabase migration.
- `3.0.0` is reserved for [17](features/17-white-label.md), which changes the Android
  `applicationId` — a build that cannot upgrade over an existing install, and the end of
  the single `releases/latest` feed [01](features/01-in-app-update.md) and
  [13](features/13-distribution-docs.md) both depend on.

## Status legend

`Ready` — spec is complete, can be built as written.
`Outline` — substance captured, expand the action items before starting.
`Built` — code is on its release branch and green, but the readiness gate is not
finished. Not shipped, and not to be treated as shipped.
`Done` — shipped; doc kept as the record of what was built.
`Dropped` — decided against; doc kept as the record of the decision.

---

## Release sequence

| # | Feature | Version | Type | Schema | Status |
|---|---|---|---|---|---|
| [01](features/01-in-app-update.md) | In-app update check | `1.6.0+6` | feature | — | Done |
| [02](features/02-shipped-data-fix.md) | Shipped-data cleanup | `1.6.0+6` | fix | — | Done |
| [03](features/03-db-integrity.md) | FK enforcement + indexes | `1.6.1+7` | fix | v4→v5 | Done |
| [04](features/04-dashboard-performance.md) | Dashboard query cleanup | `1.6.2+8` | fix | — | Done |
| [05](features/05-ledger-foundation.md) | Ledger — payments & balances | `1.7.0+9` | feature | v5→v6 | Done |
| [07](features/07-ledger-statements.md) | Ledger — statements & outstanding | `1.8.0+10` | feature | — | Done |
| [08](features/08-order-entry-swipe.md) | Digit-wheel quantity entry | `1.9.0+11` | feature | — | Done |
| — | Backup/import schema compatibility | `1.9.1+12` | fix | — | Done |
| — | Stop seeding default categories | `1.9.2+13` | fix | — | Done |
| [10a](features/10a-design-system.md) + [18](features/18-foundation-guardrails.md) | New look, faster, quantities never lost | `1.10.0+14` | feature | — | Done |
| [10b](features/10b-navigation.md) + [10b device pass](features/10b-device-pass.md) | Everything reachable in 2 taps, and the phone's list of what was wrong with it | `1.11.0+15` | feature | — | **Built, device pass planned** — on `release/1.11.0-navigation` |
| [10c](features/10c-screen-restyle.md) | Every screen rebuilt, real error messages | `1.12.0+16` | feature | — | Ready — scope reduced, see *Standing risks* |
| [12](features/12-dashboard-tabs.md) | Dashboard in tabs, updating live | `1.13.0+17` | feature | — | Outline |
| [13](features/13-distribution-docs.md) + [14a](features/14a-repository-seam.md) | Download page, and the cleanup 2.0 needs | `1.13.1+18` | fix | — | 13 Outline, 14a Ready |
| [14](features/14-supabase-auth.md) | Cloud data, login, second device | `2.0.0+19` | major | port v6 | Outline |
| [15](features/15-auto-order-suggestions.md) | Suggested orders from history | `2.1.0+20` | feature | — | Outline |
| [16](features/16-weekly-ai-report.md) | Weekly business report | `2.2.0+21` | feature | pg: `weekly_reports` | Outline |
| [17](features/17-white-label.md) | White-label | `3.0.0+22` | major | pg: `tenant_config` | Outline |

**Two rows carry two docs each.** The *Feature* column is the sentence the owner would be
told, not the doc title. That is the test a release has to pass.

- **`1.10.0+14` = 10a + 18.** 10a alone is a look-and-speed change with a red test and no
  guardrails. 18 alone is lint config and a bug fix. Together they are one release that
  can be described, and the first in the new sequence to go out fully green.
- **`1.13.1+18` = 13 + 14a.** Neither is visible in the app. Grouped so there is one
  housekeeping release before `2.0.0`, not two.

**01 and 02 shipped together as `1.6.0+6`** — the same precedent.

`1.9.1+12` and `1.9.2+13` were unplanned fixes taken ahead of the queue. They are
listed so the build-number chain reads continuously; neither has a feature doc.

---

## Why this order

**The UI foundation goes in before the remaining feature work**, and the framework-level
work goes in with it rather than after it.

**[10a](features/10a-design-system.md) shipped in `1.10.0+14`.** Tokens, `BrandConfig`,
a 15-component kit, the `autoDispose` sweep, the pre-blurred background and the splash
rework. It did not go out alone, for the reasons in
[18](features/18-foundation-guardrails.md), and the release also carried the swap from
Quicksand to **Raleway** — the owner's call, made during the device pass.

**[18](features/18-foundation-guardrails.md) ships in the same release as 10a** and it
exists for three reasons the owner named directly:

1. 10a's performance work is **half-measured**. Four of its success criteria need a
   physical device and were left unticked — cold start, list paint, frame rate, and
   subscription leaks. Code that is written but never measured is not finished, and the
   next release builds on top of it either way.
2. The lifecycle audit's **Phase 0 guardrails** cost half a day and make every later
   phase enforceable. Landing them after the refactors they govern is backwards.
3. `AGENTS.md` is five lines of style rules. It needs to be the architecture map before
   twenty screens get rebuilt, not after.

It also pulls one defect forward out of Phase 2: **order quantities typed in the last
500 ms before leaving order entry are silently discarded.** That is live data loss on the
app's busiest screen. It does not wait for the restyle.

And it fixes the red `migration_test.dart`. **The first release of the new sequence must
go out fully green** — that is what makes a push to `master` a non-event rather than
something to be nervous about.

**[10b](features/10b-navigation.md) then [10c](features/10c-screen-restyle.md)**, in that
order, unchanged. 10b rearranges where screens live; 10c rebuilds what is inside them.
Docs 12 onward then build onto already-migrated screens and no screen is built twice.

**[14a](features/14a-repository-seam.md) is not optional.** [14](features/14-supabase-auth.md)
promises that no screen file changes during the DAO port. Today 13 screen files reach
`databaseProvider` directly, 23 times. Without the seam that promise is impossible and
the Supabase port becomes a rewrite of every screen. Half a day of insurance against the
riskiest release in the plan. It rides with [13](features/13-distribution-docs.md) because
alone it is invisible — and `1.13.1+18` is then the **last stable local-only build**, the
one to fall back to if the Supabase port stalls.

The original reasoning for the first four releases, kept because it still explains the
shape of what shipped:

- **01 + 02 first** because the update channel is what makes every later release
  reach the phone without a manual WhatsApp hand-off, and because the shipped-data
  problem was live on a public repo.
- **03 before 05** because the ledger introduces `payment_allocations`, whose rows
  are meaningless if their parent payment or order can vanish.
- **05–07 next** because the shop ledger is the actual business need driving this
  round of work.

## Where the lifecycle audit phases went

[`docs/flutter-lifecycle-audit.md`](flutter-lifecycle-audit.md) proposed six phases as a
standalone ~9-day block. They ship distributed instead, each phase folded into the
release that already opens the same files. Nothing is dropped.

| Phase | Ships in | Why there |
|---|---|---|
| **0** — Guardrails (lints, CI) | [18](features/18-foundation-guardrails.md) | Must precede the refactors it governs |
| **1** — App lifecycle (container, seeding, splash route, `AppLifecycleListener`, self-correcting `todayProvider`, error observability) | [10b](features/10b-navigation.md) | 10b already rewrites `app.dart`'s router and shell. Same files, one diff |
| **2** — The three defects | Split: the debounce flush → [18](features/18-foundation-guardrails.md) (live data loss, does not wait); the rest → [10c](features/10c-screen-restyle.md) | Order entry and the payment sheet are screens 10c rebuilds anyway |
| **3** — `AsyncValue` discipline, `AppErrorView` | [10c](features/10c-screen-restyle.md), with the widget itself added to the kit in [18](features/18-foundation-guardrails.md) | Twelve error-swallowing `orElse` sites and sixteen raw `Text('Error: $e')` sites are all in screens |
| **4** — Riverpod modernisation, dashboard `StreamProvider`s | [12](features/12-dashboard-tabs.md) | 12 needs lazy per-tab providers regardless. `_refreshDashboard` dies there |
| **5** — Repository seam, `didUpdateWidget`, `StatefulWidget` → `ConsumerWidget` | [14a](features/14a-repository-seam.md) | It is the precondition for the Supabase port, not general cleanup |
| **6** — Theme and router from the tree | Mostly landed in [10a](features/10a-design-system.md); the remainder — `routerProvider` and the 96 global colour reads — in [10c](features/10c-screen-restyle.md) | 10c drives the deprecated-alias count to zero, and those aliases *are* the 96 colour reads |

## Schema

**The Drift chain is frozen at v6.** With counter stock dropped and shop exclusion
dropped, there is no v7 and no v8. This is the single largest simplification in the
revised plan and it has a specific consequence worth stating:

> **`lib/services/backup_service.dart` stops being a recurring trap.** It was the
> standing risk in every schema doc. With the chain frozen, it needs to round-trip
> exactly what exists today — and that makes it a stable, trustworthy source for
> [14](features/14-supabase-auth.md)'s one-time import.

| Version | Introduced by | Change |
|---|---|---|
| v6 | *shipped* | current, and final for Drift — payments, allocations, shop opening balance |
| pg | [16](features/16-weekly-ai-report.md) | `weekly_reports` — post-port, Postgres only, server-written |
| pg | [17](features/17-white-label.md) | `tenant_config` — post-port, one row per tenant project |

Neither `pg` row is a `backup_service.dart` obligation — by then Drift and the JSON
backup path are gone.

If a schema change ever does become necessary again, the old rule returns in full:
**extend `backup_service.dart` in the same commit**, and run the full upgrade chain
against a real v4 install before shipping.

---

## Standing risks

- ~~**10a is uncommitted.**~~ Closed 2026-08-29 — shipped in `1.10.0+14`.
- **There is no CI gate.** Deferred by the owner on 2026-08-28, so `flutter analyze` and
  `flutter test` are run by hand. Steps 2 and 3 of the readiness gate are therefore only
  as reliable as the person running them.
- **The 10a performance work has no baseline.** All four criteria were verified on the
  owner's device on 2026-08-29 and all four passed, but the figures were not written
  down. There is a pass, not a number to regress against. Capture them the next time
  the phone is out — [10b](features/10b-navigation.md) rewrote the router and **deleted
  the splash route entirely**, which is exactly the work cold start would notice. That
  measurement is now overdue rather than merely nice to have.
- **10b is built but ungated, and the owner revised it on 2026-08-30.** Five slots
  instead of four, no centre FAB, a Finances tab, and the app opens on the Overview.
  See that doc's *Revised by the owner* table. Its remaining criteria need the phone
  and are listed in *Build notes*. `pubspec.yaml` is deliberately still `1.10.0+14`,
  so merging the branch as it stands would not cut a release — bump to `1.11.0+15`
  as the last commit once the device pass is done.
- **Some of 10c landed early.** The 1.11 branch rebuilt the three master lists on
  the kit and routed every currency site through `money.dart`, because the owner hit
  both as live defects. `check_tokens.sh` is at **354**, from 396. 10c's scope
  shrinks accordingly; it is still the release that sets `SCREENS_BLOCKING=1`.
- **The face changed twice, and the sizes have not been re-read since.** Quicksand →
  Raleway (2026-08-29), then Raleway → **Bricolage Grotesque**
  ([10b device pass](features/10b-device-pass.md), 2026-09-05). Raleway has a smaller
  x-height than Quicksand and Bricolage Grotesque has a larger one than either, so the
  same `fontSize:` has read light and now reads heavy.
  [10c](features/10c-screen-restyle.md) touches all 198 of them and is the place to
  settle it — once, against the face the app is actually shipping.
- **Money arithmetic is thinly tested.** Two things carry real money: FIFO allocation
  (05) and the quantity wheel with its clamp (08). Both have tests. Nothing else in the
  UI needs them.
- **`migration_test.dart` `v4 -> v5 upgrade` fails**, and failed before 10a started. It
  is a genuine schema-migration bug in an area 10a does not touch. With the chain frozen
  at v6 it will not get worse, but it should be fixed in
  [18](features/18-foundation-guardrails.md) before the guardrails make CI blocking —
  a red test that CI is taught to tolerate is a red test forever.
  **Fixed in `0f08741`.** The chain now runs through v6 and the suite is green.
- **APK is ~60 MB universal.** Split-per-ABI was rejected deliberately (archived
  release planner, Q4) so users never have to pick a file. Doc 02 removed ~1.7 MB and
  10a a further 145 KB. Beyond that, a real `--analyze-size` pass is needed before
  claiming any further reduction — no size work on guesswork.
- **Design-system drift.** [10a](features/10a-design-system.md) added tokens and
  `tool/check_tokens.sh`; [10c](features/10c-screen-restyle.md) makes it blocking in CI.
  Until 10c ships, that script reports but does not fail, and the app contains both
  idioms. If 10c is deferred, the ratchet is what stops the codebase sliding back —
  do not disable it to land something quickly.
- **Doc 14 touches every DAO.** What makes it survivable is
  [14a](features/14a-repository-seam.md) landing first. If a screen has to change during
  the port, the port is being done wrong.
- **Online-only is an accepted cost.** Order entry at 5 a.m. with no signal fails
  outright after 14. The mitigation is written down in that doc and deliberately not
  built until it hurts.


Nine releases now, each with a sentence you'd actually say:

Version	What the user gets
1.10.0+14	New look, faster, quantities never lost
1.11.0+15	Everything reachable in 2 taps
1.12.0+16	Every screen rebuilt, real error messages
1.13.0+17	Dashboard in tabs, updating live
1.13.1+18	Download page, and the cleanup 2.0 needs
2.0.0+19	Cloud data, login, second device
2.1.0+20	Suggested orders from history
2.2.0+21	Weekly business report
3.0.0+22	White-label