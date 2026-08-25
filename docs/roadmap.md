# Milano Orders — Roadmap

> Last updated: 2026-08-23
> Current shipped version: **1.5.0+5** · schema v4

This is the index. Every feature has its own self-contained plan in `docs/features/`,
sized to ship as **one release**. Build one, bump `pubspec.yaml`, push to `master`,
let CI cut the release, move to the next.

Superseded plans (v1–v5 roadmaps, the original PRD, the release planner) live in
`docs/archive/`. They are history — read them for rationale, never for current scope.

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

## Status legend

`Ready` — spec is complete, can be built as written.
`Outline` — substance captured, expand the action items before starting.
`Done` — shipped; doc kept as the record of what was built.

---

## Release sequence

| # | Feature | Version | Type | Schema | Status |
|---|---|---|---|---|---|
| [01](features/01-in-app-update.md) | In-app update check | `1.6.0+6` | feature | — | Ready |
| [02](features/02-shipped-data-fix.md) | Shipped-data cleanup | `1.6.0+6` | fix | — | Ready |
| [03](features/03-db-integrity.md) | FK enforcement + indexes | `1.6.1+7` | fix | v4→v5 | Ready |
| [04](features/04-dashboard-performance.md) | Dashboard query cleanup | `1.6.2+8` | fix | — | Ready |
| [05](features/05-ledger-foundation.md) | Ledger — payments & balances | `1.7.0+9` | feature | v5→v6 | Ready |
| [06](features/06-ledger-manual-allocation.md) | Ledger — manual allocation | `1.9.0+11` | feature | — | Deferred |
| [07](features/07-ledger-statements.md) | Ledger — statements & outstanding | `1.8.0+10` | feature | — | Done |
| [08](features/08-order-entry-swipe.md) | Swipe-by-5 order entry | `1.10.0+12` | feature | — | Ready |
| [09](features/09-shop-exclusion.md) | Exclude shops from grand total | `1.11.0+13` | feature | v6→v7 | Ready |
| [10](features/10-nav-restructure.md) | Navigation + settings restructure | `1.12.0+14` | feature | — | Outline |
| [11](features/11-counter-stock.md) | Counter stock (Cafe Milano) | `1.13.0+15` | feature | v7→v8 | Outline |
| [12](features/12-dashboard-tabs.md) | Dashboard tabs + reports | `1.14.0+16` | feature | — | Outline |
| [13](features/13-distribution-docs.md) | Download page, agent docs, tests | `1.15.0+17` | feature | — | Outline |
| [14](features/14-supabase-auth.md) | Supabase, auth & roles | `2.0.0+18` | major | port v8 | Outline |

**01 and 02 ship together as `1.6.0+6`** — one release, two docs. Everything after
that is one doc per release.

---

## Why this order

The first three releases clear ground the ledger has to stand on:

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

Order after `1.6.x` is adjustable — the ledger docs depend only on 03, and the UX
docs (08, 10) depend on nothing. Rearrange freely, but keep 03 ahead of 05.

## Schema migration chain

| Version | Introduced by | Change |
|---|---|---|
| v4 | *shipped* | current — categories, product category FK |
| v5 | [03](features/03-db-integrity.md) | four indexes on order/line hot paths |
| v6 | [05](features/05-ledger-foundation.md) | `payments`, `payment_allocations`, shop opening balance |
| v7 | [09](features/09-shop-exclusion.md) | `shops.count_in_total` |
| v8 | [11](features/11-counter-stock.md) | `counter_stock` |

> These schema numbers are **reassigned** relative to the archived v5 roadmap,
> which had planned v5 for `countInTotal`. Ignore the archived numbering.

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
  FIFO allocation (05), the swipe quantity clamp (08), stock derivation (11). Each
  of those docs adds tests. The rest of the UI does not need them.
- **APK is ~60 MB universal.** Split-per-ABI was rejected deliberately (archived
  release planner, Q4) so users never have to pick a file. Doc 02 removes ~1.7 MB
  of it. Beyond that, a real `--analyze-size` pass is needed before claiming any
  further reduction is available — no size work is planned on guesswork.
- **Doc 14 touches every DAO.** What makes it survivable is that provider
  signatures do not change. If a screen has to change during the port, the port is
  being done wrong.
