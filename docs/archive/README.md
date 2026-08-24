# Archived plans

**These are superseded. Do not build from them.**

The live plan is [`docs/roadmap.md`](../roadmap.md) and the per-feature docs in
[`docs/features/`](../features/). Everything here is kept for the reasoning behind
decisions already taken — read it for *why*, never for *what next*.

| Doc | What it was | Outcome |
|---|---|---|
| `bakery-order-app-PRD.md` | Original product requirements | Delivered |
| `implementation-plan.md` | v1.0 build, Phases 1–10 | Shipped |
| `v2-implementation-plan.md` | Rebrand to "Milano Orders", two-way pricing, splash | Shipped |
| `v3-UI-IMPLEMENTATION-PLAN.md` | Home/nav/splash/background restyle, Poppins fonts | Shipped — Poppins later replaced by Quicksand (`d9e6799`) |
| `dashboard_plan.md` | Dashboard detail spec | Shipped as v1.5 |
| `v4-implementation-plan.md` | v1.2–v1.7 roadmap | Phases 1–4 shipped. Phases 5–6 (ledger) never built — carried forward into features [05](../features/05-ledger-foundation.md), [06](../features/06-ledger-manual-allocation.md) and [07](../features/07-ledger-statements.md) |
| `v5-revamp-plan.md` | UX + modules + cloud roadmap | Never started — broken up into features [08](../features/08-order-entry-swipe.md)–[14](../features/14-supabase-auth.md) |
| `release-planner.md` | Signing, APK size, GitHub Release CI | Shipped — `.github/workflows/release.yml`. Still the reference for keystore setup and how to cut a release |

## Two things that carry forward

**Decisions taken 2026-08-19** (recorded in `v5-revamp-plan.md`) remain binding and
are not re-litigated in the new docs: Supabase online-only, counter stock limited to
Cafe Milano, three role tiers, hybrid navigation, swipe-by-5 on a flat list, and
UX-before-cloud sequencing.

**Schema numbering was reassigned.** `v5-revamp-plan.md` planned schema v5 for
`countInTotal`; the live roadmap gives v5 to indexes and v7 to `countInTotal`. Use
the chain in [`roadmap.md`](../roadmap.md), not the one here.
