# AGENTS.md — Milano Orders

Read this file first. It gives the rules. The other docs give the facts.

Update this file in the same commit as any change to a rule below.

> Last verified against `1.10.0+14` plus the 1.11 work on
> `release/1.11.0-navigation`, schema v6, on 2026-08-30.

---

## Working rules

- Write short sentences. 10 to 15 words maximum.
- Use plain English. Use no jargon.
- Give no preamble. Give the result first.
- Use the tool first. Do not explain unless the user asks.
- Keep code normal. Compress the English only.
- Do not assume and do not overdo. Ask when you are not sure.

[`claude.md`](claude.md) gives the working philosophy.

---

## What the app is

Milano Orders is a single-user Android app. One bakery bakes in one kitchen. It supplies
about 18 retail shops each day.

The app does five jobs, in the order of the day:

1. Catalog — the products, the categories, and one price per shop.
2. Order entry — the quantities for the day, per shop.
3. Production — the Kitchen screen makes one bake list from all orders.
4. Billing — the totals for the day, per shop.
5. Collection — the payments, the FIFO allocation, the balances, and the PDF statements.

**The app does not count inventory.** It holds no stock levels, no daily counts, and no
waste figures. The owner dropped this feature on 2026-08-28. See
[`docs/features/11-counter-stock.md`](docs/features/11-counter-stock.md).

**The app has one user.** It has no roles, no permissions and no login. It is local-first
on SQLite and stays that way — the Supabase plan was dropped on 2026-09-14
([`docs/archive/14-supabase-auth.md`](docs/archive/14-supabase-auth.md)). No code must
anticipate roles or a server.

---

## The layering rule

This is the most important rule in the repository.

```
lib/database/tables/   Drift table definitions
        ↓
lib/database/daos/     queries — the only place that holds SQL
        ↓
lib/providers/         Riverpod providers — the only place that calls a DAO
        ↓
lib/screens/           UI. It reads AsyncValue. It knows nothing about Drift
lib/widgets/
```

A screen must not reach past a provider.

24 screen calls break this rule today, across 12 files. They all call
`ref.read(databaseProvider)` directly. This is a known defect. The doc that was going to
close it is dropped ([`docs/archive/14a-repository-seam.md`](docs/archive/14a-repository-seam.md)) —
fix these when you are already in the file for another reason, and do not add new ones.

The read path is already correct. Providers wrap the DAO `watch*` queries. Screens read
`AsyncValue`. Only the writes break the rule.

---

## Rules that must not be broken

1. Never commit to `master`. Work on a release branch and merge when it is finished.
2. Never call `databaseProvider` from a screen or a widget. Use a provider.
3. Change `backup_service.dart` in the same commit as any schema change.
4. Keep `dev/` in `.gitignore`. Never commit real business data.
5. Never disable `tool/check_tokens.sh`. The violation count can only decrease.
6. Never write a brand name into the UI. Read it from `BrandConfig`.
7. Format all money with `lib/utils/money.dart`. Never write `₹` or a
   `NumberFormat` pattern — the grouping is Indian and comes from `BrandConfig`.
8. Do not change a provider signature. This is a decision, not a refactor.
9. Do not add roles, permissions, auth or server code. There is no plan for any of it.
10. Use the `AppRoutes` constants, and its builders for anything with a `:param`.
    Never write a route string.
11. No bare `// ignore:`. Every one names the reason and the doc that removes it.
12. Add a destination in `lib/widgets/shell/destinations.dart` and nowhere else.
13. One `AppLifecycleListener` for the app. It is in `AppLifecycleScope`.
14. Read the wall clock through `package:clock` when the answer is *what day is it*.
15. Do no work in `main()` before `runApp`. Bootstrap belongs in a provider.
16. One confirm dialog: `confirmDestructive`. Never hand-roll an `AlertDialog`
    with Cancel and a destructive action.
17. Never animate inside `itemBuilder`. Fade the list, not the row.
18. Update this file when a rule above changes.

---

## Where to find things

| File | What it holds |
|---|---|
| [`docs/roadmap.md`](docs/roadmap.md) | **The index.** The release sequence, the versions, and what was dropped. Start here |
| [`docs/architecture.md`](docs/architecture.md) | The stack, the directory map, the data model, the routes, and the design system |
| [`docs/development.md`](docs/development.md) | How to set up, test, build, and release |
| `docs/features/NN-*.md` | One plan per release |
| [`docs/app-audit.md`](docs/app-audit.md) | The state of the structure, the visual design, and the speed |
| [`docs/flutter-lifecycle-audit.md`](docs/flutter-lifecycle-audit.md) | The state of the app lifecycle, the async safety, and Riverpod |
| `docs/archive/` | Old plans. History only. Never current scope |

The owner revised the scope on 2026-08-28. If a feature doc disagrees with the roadmap,
the roadmap is correct.
