# 13 — Download page, agent docs & test harness

| | |
|---|---|
| **Target version** | `1.15.0+19` |
| **Type** | Feature |
| **Schema** | No change |
| **Requires** | [01](01-in-app-update.md) — shares its release-lookup logic |
| **Status** | **Outline** — expand action items before starting |

## Why

Three loose ends, grouped because none justifies its own release and all three are
about the project rather than the product. The natural place for them is immediately
before the Supabase migration, which is the point at which the codebase most needs to
be legible to someone (or something) that did not write it.

## Outline of work

### Download page

- A single static `index.html` on GitHub Pages that fetches
  `api.github.com/repos/JuniorRaja/cafe-milano-app/releases/latest` client-side and
  renders a download button. Public repo, so unauthenticated — the same property
  [doc 01](01-in-app-update.md) depends on, and the reason doc 02 kept the repo public.
- No build step, no framework. If it needs a bundler it has been over-designed.
- This is the link to send a **new** user. Existing users get updates in-app from
  doc 01; this covers first install and re-install.

### Agent docs

- `AGENTS.md` — architecture map, data model, module boundaries, local setup, build and
  release procedure, and the conventions that must not be broken.
- `claude.md` keeps the working rules (ask don't assume; simplest thing first; don't
  touch unrelated code; flag uncertainty) and links to `AGENTS.md` for the facts.
- Worth writing only if kept current. A stale architecture doc is worse than none,
  because it is believed. Decide who updates it and when — the honest answer is
  probably "in the same PR as any schema change", alongside `backup_service.dart`.

### Test harness

- `docs/testing-checklist.md` — a scripted device walkthrough per module: install APK →
  order entry → kitchen → counter stock → billing → ledger → screenshot each.
  Not a unit-test framework; a repeatable smoke pass before each release.
- Extend `test/` for anything carrying money or counts still uncovered. By this point
  docs 05, 06, 08 and 11 have each added their own tests; this is the sweep for what
  fell between them.
- Be honest about the boundary: the UI does not need unit tests. Money arithmetic,
  quantity clamps and stock derivation do.

## Success criteria

- [ ] The download page loads with no build step and links the current release APK.
- [ ] The page works from a phone browser — that is where it will actually be opened.
- [ ] `AGENTS.md` is accurate against the shipped schema and module layout on the day
      it lands.
- [ ] The testing checklist can be followed end to end by someone who has not used the
      app, and every step has an unambiguous pass/fail.
- [ ] `flutter test` passes, and covers FIFO allocation, the swipe clamp, and stock
      derivation.
