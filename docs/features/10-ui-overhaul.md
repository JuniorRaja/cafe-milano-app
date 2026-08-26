# 10 — UI overhaul (block index)

| | |
|---|---|
| **Target versions** | `1.7.1+10` → `1.8.1+12`, three releases |
| **Type** | Foundation |
| **Schema** | No change, in any part |
| **Status** | Block index — build [10a](10a-design-system.md), then [10b](10b-navigation.md), then [10c](10c-screen-restyle.md) |

## Why this is a block, not a doc

Doc 10 was opened as "Navigation + settings restructure". Auditing the app to plan it
([`docs/app-audit.md`](../app-audit.md)) showed navigation is one of three faults, and
the smallest of them:

1. **There is no design system.** 14 font sizes, 111 ad-hoc greys, 8 corner radii,
   117 spacing literals, two competing header idioms, and `Theme.of(context).textTheme`
   used exactly twice in 12,029 lines. Restructuring navigation without fixing this
   produces a well-organised app that still looks unfinished.
2. **68% of routes sit behind a tab called "Profile"**, including the shop ledger, four
   taps deep. This is the original doc 10.
3. **The app is slow for reasons that have nothing to do with the database.** A
   runtime-blurred full-screen PNG repainting under every screen, a deliberate 360 ms
   list stagger, a 1.2 s splash animation gate, and 0 of 35 providers using
   `autoDispose`.

Attempting all three as one release means one commit that changes every file in `lib/`
with no reviewable seam and no working intermediate state. Split three ways, each part
ships on its own and the app is better after each.

The [roadmap](../roadmap.md) already sets this precedent for doc 14 — "split it into
its own numbered sequence rather than attempting it as one."

## The three parts

| Doc | Ships | What it does | Movable? |
|---|---|---|---|
| [10a — Design system & UI foundation](10a-design-system.md) | `1.7.1+10` | Tokens, `BrandConfig`, component kit, the four performance fixes | **No** — 10b and 10c are written against it |
| [10b — Navigation & settings restructure](10b-navigation.md) | `1.8.0+11` | Drawer, 5-slot bottom bar, quick-action FAB, `/profile/*` → `/settings/*`, Outstanding as a destination | **No** — depends on 10a's kit |
| [10c — Screen restyle](10c-screen-restyle.md) | `1.8.1+12` | All 20 remaining screens rebuilt on the kit; the token ratchet closed | **Yes** — nothing depends on it |

**10a and 10b are the foundation and ship first, in that order.** 10c is the only part
with no downstream dependency; if feature work is more urgent, it can slide behind
[06](06-ledger-manual-allocation.md) and [07](07-ledger-statements.md) without blocking
anything. It should not slide behind [08](08-order-entry-swipe.md) — that doc adds a
swipe gesture to order entry, and 10c fixes the per-tap full-list rebuild on the same
screen.

**10c migrates every remaining screen, including ones later docs will extend.** That is
what makes the sequencing decision pay: docs 06–12 then add their features to
already-migrated screens, and no screen is built twice.

## Decisions taken 2026-08-26, not reopened

| Question | Decision |
|---|---|
| Sequencing | **Foundation now.** 10a + 10b before [06](06-ledger-manual-allocation.md). Docs 06–13 are then built directly in the new language and never restyled twice |
| Side menu reach | **Mobile drawer only. Never desktop.** No rail, no breakpoint layouts, no wide-screen work now or later. The desktop sidebar in the reference is a *styling* reference for the drawer |
| Centre FAB | **Quick-action sheet** — New order · Record payment · Add shop. Replaces today's FAB-opens-Dashboard |
| White-labelling | **Constrain now, ship later.** Brand colour, logo and app name resolve through one `BrandConfig` from 10a onward; "Milano" stops being hardcoded in UI. The product change itself is [17](17-white-label.md) |

## What does not change

- **No schema change in any of the three parts.** Not one column.
- **Almost no DAO change.** Every finding in the audit sits above the provider line —
  the same line [doc 14](14-supabase-auth.md) promises not to cross — so the two pieces
  of work do not collide. The single exception is named in
  [10b](10b-navigation.md): two additive, read-only outstanding queries on
  `ledger_dao.dart`, over tables that already exist, so the drawer can carry the
  all-shops outstanding figure the app cannot currently show at all.
- **No functionality is removed.** Every route reachable before 10b is reachable after
  it. This is rearrangement and restyling, not a feature cut.
- **The brand palette is unchanged.** Gold `#FFC000`, espresso `#4A2C2A` and cream
  `#FFFBF5` are already the reference palette. This is not a rebrand — see
  [audit §3.5](../app-audit.md).

## Success criteria for the block

Each part carries its own detailed criteria. These are the ones that only make sense
across all three:

- [ ] After 10c, `grep -rn "Colors\.grey" lib/screens lib/widgets` returns **zero**
      results outside `lib/widgets/ui/`.
- [ ] After 10c, no `fontSize:` literal exists in `lib/screens/`.
- [ ] Reaching any destination in the app takes at most **2 taps** from any screen.
- [ ] Cold start to first interactive frame is under **1.2 s** on the owner's device,
      measured the same way before and after.
- [ ] A 30-minute session touching every module ends with no more live Drift stream
      subscriptions than it started with, plus the ones currently on screen.
- [ ] The app contains no hardcoded occurrence of "Milano" in any UI string.
