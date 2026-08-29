# 13 — Download page & test harness

| | |
|---|---|
| **Target version** | `1.13.1+18` — **ships with [14a](14a-repository-seam.md)** |
| **Type** | Feature |
| **Schema** | No change |
| **Requires** | [01](01-in-app-update.md) — shares its release-lookup logic |
| **Status** | **Outline** — expand action items before starting |

## Why

Two loose ends, grouped because neither justifies its own release and both are about the
project rather than the product.

This doc used to carry a third. **The agent docs moved to
[18](18-foundation-guardrails.md)** and ship early, on the reasoning that an architecture
map written *after* twenty screens are rebuilt documents a codebase nobody had while
rebuilding it.

## Outline of work

### Download page

- A single static `index.html` on GitHub Pages that fetches
  `api.github.com/repos/JuniorRaja/cafe-milano-app/releases/latest` client-side and
  renders a download button. Public repo, so unauthenticated — the same property
  [doc 01](01-in-app-update.md) depends on, and the reason doc 02 kept the repo public.
- No build step, no framework. If it needs a bundler it has been over-designed.
- This is the link to send a **new** user. Existing users get updates in-app from
  doc 01; this covers first install and re-install.

### Test harness

- `docs/testing-checklist.md` — a scripted device walkthrough per module: install APK →
  order entry → kitchen → billing → ledger → screenshot each.
  Not a unit-test framework; a repeatable smoke pass before each release.
- Extend `test/` for anything carrying money still uncovered. By this point docs 05, 08
  and 18 have each added their own tests; this is the sweep for what fell between them.
- Be honest about the boundary: the UI does not need unit tests. Money arithmetic and
  quantity clamps do.

## Success criteria

- [ ] The download page loads with no build step and links the current release APK.
- [ ] The page works from a phone browser — that is where it will actually be opened.
- [ ] `AGENTS.md`, `docs/architecture.md` and `docs/development.md` still match the
      shipped schema and module layout. All three landed in
      [18](18-foundation-guardrails.md); this is the checkpoint that they have not rotted.
- [ ] The testing checklist can be followed end to end by someone who has not used the
      app, and every step has an unambiguous pass/fail.
- [ ] `flutter test` passes, and covers FIFO allocation and the quantity-wheel
      composition.
