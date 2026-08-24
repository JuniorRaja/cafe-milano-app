# 10 — Navigation + settings restructure

| | |
|---|---|
| **Target version** | `1.12.0+14` |
| **Type** | Feature |
| **Schema** | No change |
| **Status** | **Outline** — expand action items before starting |

## Why

The bottom bar currently carries things touched daily and things configured monthly
with equal prominence. By the time docs 05–12 land there are ~28 destinations, and a
four-slot bottom bar cannot address them.

Decision taken 2026-08-19, not reopened: **hybrid navigation** — bottom bar for daily
jobs, drawer for masters, reports and settings.

```
Bottom nav (FAB gap preserved):  Home · Billing  [ FAB → Dashboard ]  Kitchen · Counter
Drawer:  Dashboard
         MASTERS   Shops · Categories · Products · Price Matrix · Standing Orders
         REPORTS   Daily Sales · Product Movement · Counter Stock · Shop Ledger · Outstanding
         SETTINGS  Business Info · Dashboard · Backup & Restore · Updates · About
```

## Outline of work

- `lib/app.dart` — replace the Profile branch with a **Counter** branch (`/counter`).
  If [doc 11](11-counter-stock.md) has not shipped, ship a placeholder. Update
  `_topLevelPaths`.
- `lib/app.dart` — `_ScaffoldWithNavBar` gains a `Drawer`. Keep the FAB → Dashboard;
  it works and the owner uses it daily.
- `lib/widgets/floating_nav_bar.dart` — swap the person icon for a counter/inventory
  icon. The 2 + gap + 2 layout is unchanged.
- `lib/widgets/app_drawer.dart` — new. Grouped sections, business name + logo header,
  version footer.
- `lib/screens/profile/profile_screen.dart` → `lib/screens/settings/settings_screen.dart`.
  Routes move `/profile/*` → `/settings/*` **with redirects from the old paths** —
  there are deep links into these routes throughout the app.
- Settings redesign: grouped cards with section headers, a live-filter search field,
  and each tile showing **current state** rather than static prose — "18 active,
  2 excluded from total"; "212 of 504 prices set" in amber when incomplete; "last
  exported 3 days ago". The search field is what makes 28 destinations navigable.
- `lib/providers/session_provider.dart` — new, one line: `currentRoleProvider` returns
  `AppRole.owner`, hardcoded. Drawer and settings gate off it from now on;
  [doc 14](14-supabase-auth.md) swaps the body for the real session.
  **No local login screen** — a fake auth built now is thrown away in doc 14.
- The REPORTS section only lights up entries whose backing feature has shipped. Decide
  whether unshipped entries are hidden or shown-disabled, and be consistent.

## Success criteria

- [ ] Every route reachable before the change is still reachable, via redirects from
      `/profile/*`. Enumerate them; do not sample.
- [ ] Reaching any master takes at most 2 taps from any screen.
- [ ] Settings search filters to a destination in one keystroke.
- [ ] Back from a drawer destination returns to the originating tab, not to the drawer.
- [ ] Each settings tile's state summary is accurate against the real dataset.
- [ ] Role gating is present and inert — verified by inspection, since it cannot be
      exercised until doc 14.
