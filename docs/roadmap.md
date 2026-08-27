# Milano Orders — Roadmap

> Last updated: 2026-08-27
> Current shipped version: **1.9.0+11** · schema v6

This is the index. Every feature has its own self-contained plan in `docs/features/`,
sized to ship as **one release**. Build one, bump `pubspec.yaml`, push to `master`,
let CI cut the release, move to the next.

Superseded plans (v1–v5 roadmaps, the original PRD, the release planner) live in
`docs/archive/`. They are history — read them for rationale, never for current scope.

[`docs/app-audit.md`](app-audit.md) is the current-state record of the app as of
`1.7.0+9` — structure, UI, and the five specific causes of slowness. The
[10](features/10-ui-overhaul.md) block is built from it.

---

## How a release works

1. Pick the next feature doc. Work through its **Action items**.
2. Verify its **Success criteria**. All of them.
3. Bump `version:` in `pubspec.yaml` to the doc's target version.
4. Commit, push to `master`.
5. `.github/workflows/release.yml` detects the version change, builds a signed
   universal APK, tags, and publishes a GitHub Release with auto-generated notes.

One feature per release. If a feature turns out bigger than its doc, split it and
give the second half its own doc and its own version — do not let a release grow.

## Versioning rules

| Change | Bump | Example |
|---|---|---|
| New user-facing capability | **minor** | `1.6.0` → `1.7.0` |
| Fix, hardening, performance, refactor | **patch** | `1.6.0` → `1.6.1` |
| Supabase / auth / multi-user | **major** | `1.x` → `2.0.0` |

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
`Done` — shipped; doc kept as the record of what was built.

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
| [10a](features/10a-design-system.md) | Design system & UI foundation | `1.9.1+12` | foundation | — | Ready |
| [10b](features/10b-navigation.md) | Navigation & settings restructure | `1.10.0+13` | feature | — | Ready |
| [10c](features/10c-screen-restyle.md) | Screen restyle | `1.10.1+14` | foundation | — | Ready |
| [06](features/06-ledger-manual-allocation.md) | Ledger — manual allocation | `1.11.0+15` | feature | — | Deferred |
| [09](features/09-shop-exclusion.md) | Exclude shops from grand total | `1.12.0+16` | feature | v6→v7 | Ready |
| [11](features/11-counter-stock.md) | Counter stock (Cafe Milano) | `1.13.0+17` | feature | v7→v8 | Outline |
| [12](features/12-dashboard-tabs.md) | Dashboard tabs + reports | `1.14.0+18` | feature | — | Outline |
| [13](features/13-distribution-docs.md) | Download page, agent docs, tests | `1.15.0+19` | feature | — | Outline |
| [14](features/14-supabase-auth.md) | Supabase, auth & roles | `2.0.0+20` | major | port v8 | Outline |
| [15](features/15-auto-order-suggestions.md) | Auto order suggestions | `2.1.0+21` | feature | — | Outline |
| [16](features/16-weekly-ai-report.md) | Weekly AI business report | `2.2.0+22` | feature | pg: `weekly_reports` | Outline |
| [17](features/17-white-label.md) | White-label | `3.0.0+23` | major | pg: `tenant_config` | Outline |

**01 and 02 shipped together as `1.6.0+6`** — one release, two docs. Everything after
that is one doc per release.

Doc 10 was a single "Navigation + settings restructure" outline. Auditing the app to
plan it showed navigation was the smallest of three faults, so it became the
[10](features/10-ui-overhaul.md) block — three releases, foundation first. Its index
carries the reasoning and the four decisions taken 2026-08-26.

---

## Why this order

**Docs 01–05, 07, and 08 have shipped.** The sequence from here is set by one
decision, taken 2026-08-26: **the UI foundation goes in before the remaining feature
work.** Docs 06–13 each add screens; building them on the current UI means restyling
every one of them later. Building them after [10a](features/10a-design-system.md) and
[10b](features/10b-navigation.md) means no screen is built twice. Three foundation
releases now cost less than eight restyles later.

[10c](features/10c-screen-restyle.md) is the movable one — nothing depends on it, so it
can slide behind 06 and 07 if feature work is more urgent. **The plan said it must not
slide behind [08](features/08-order-entry-swipe.md)**, since 08 adds a repeating
long-press to the order-entry screen whose per-tap full-list rebuild 10c fixes — but
08 shipped 2026-08-27, ahead of the whole 10 block, on direct request. 10c's rebuild
fix is now a retrofit onto a screen already taking a rebuild seven times a second in
production, not a preventive one. Manual testing on a physical device confirmed the
feature works; no fps profiling was done, so the rebuild cost 10c is meant to fix has
not actually been measured under 08's long-press load. 10c should not slide further.

The original reasoning for the first four releases, kept because it still explains the
shape of what shipped:

- **01 + 02 first** because the update channel is what makes every later release
  reach the phone without a manual WhatsApp hand-off, and because the shipped-data
  problem is live right now on a public repo.
- **03 before 05** because the ledger introduces `payment_allocations`, whose rows
  are meaningless if their parent payment or order can vanish. Foreign keys are
  currently declared but not enforced (see doc 03). Turning enforcement on *after*
  money tables exist means retrofitting integrity onto real financial data.
- **05–07 next** because the shop ledger is the actual business need driving this
  round of work. Order entry, navigation and counter stock are improvements to
  things that already work.

Order after the 10 block is adjustable — the ledger docs depend only on 03.
[08](features/08-order-entry-swipe.md) depended on nothing and has already shipped
ahead of the block. Rearrange the rest freely, but keep 10a ahead of 10b ahead of 10c.

## Schema migration chain

| Version | Introduced by | Change |
|---|---|---|
| v6 | *shipped* | current — payments, allocations, shop opening balance |
| v7 | [09](features/09-shop-exclusion.md) | `shops.count_in_total` |
| v8 | [11](features/11-counter-stock.md) | `counter_stock` |
| pg | [16](features/16-weekly-ai-report.md) | `weekly_reports` — post-port, Postgres only |
| pg | [17](features/17-white-label.md) | `tenant_config` — post-port, one row per tenant project |

> These schema numbers are **reassigned** relative to the archived v5 roadmap,
> which had planned v5 for `countInTotal`. Ignore the archived numbering.
>
> The [10](features/10-ui-overhaul.md) block adds **no schema hop at all** — it is
> entirely above the DAO line, which is also the line
> [14](features/14-supabase-auth.md) promises not to cross.

The Drift chain genuinely ends at **v8**. The two `pg` rows are created in Postgres
after [14](features/14-supabase-auth.md)'s port, and **neither is a
`backup_service.dart` obligation** — by then Drift and the JSON backup path are gone,
and `weekly_reports` is server-written and reconstructible.

**`lib/services/backup_service.dart` must be extended in the same commit as any
schema change.** It is the recurring trap in this codebase — it has to round-trip
every new table and column, and it is the only clean source for the Supabase
import in doc 14. An older backup imported into a newer app must fail loudly,
never silently drop columns.

Run the full upgrade chain against a real v4 install before shipping each schema
hop. `drift_dev` schema-snapshot tests are worth the setup at doc 05.

---

## Standing risks

- **Backup service drift.** See above. Every schema doc restates it; that repetition
  is deliberate.
- **Money arithmetic is untested.** Three things carry real money or real counts:
  FIFO allocation (05), the quantity wheel and its clamp (08), stock derivation (11). Each
  of those docs adds tests. The rest of the UI does not need them.
- **APK is ~60 MB universal.** Split-per-ABI was rejected deliberately (archived
  release planner, Q4) so users never have to pick a file. Doc 02 removes ~1.7 MB
  of it. Beyond that, a real `--analyze-size` pass is needed before claiming any
  further reduction is available — no size work is planned on guesswork.
- **Design-system drift.** [10a](features/10a-design-system.md) adds tokens and
  [10c](features/10c-screen-restyle.md) makes `tool/check_tokens.sh` blocking in CI.
  Until 10c ships, that script reports but does not fail, and the app contains both
  idioms. If 10c is deferred, the ratchet is what stops the codebase sliding back —
  do not disable it to land something quickly.
- **Doc 14 touches every DAO.** What makes it survivable is that provider
  signatures do not change. If a screen has to change during the port, the port is
  being done wrong.
