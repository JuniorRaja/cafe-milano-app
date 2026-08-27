# 14 — Supabase, auth & three-tier roles

| | |
|---|---|
| **Target version** | `2.0.0+20` |
| **Type** | Major |
| **Schema** | Port v8 to Postgres |
| **Requires** | Everything above shipped and stable on Drift |
| **Status** | **Outline** — expand into its own multi-part plan before starting |

## Why

The big one, and the reason `2.0.0` is reserved. Everything above ships on Drift
first, then the data layer swaps underneath **unchanged Riverpod providers**.

Decisions taken 2026-08-19, not reopened:

| Question | Decision |
|---|---|
| Backend | Supabase, **online-only** — no offline sync layer |
| Roles | **Three tiers** — owner / manager / staff |
| Sequencing | UX and features first on Drift, Supabase **last** |

This doc is an outline of a release that is really several. When it comes up, split it
into its own numbered sequence (`14a`, `14b`, …) rather than attempting it as one.
A single release that changes the storage engine, adds authentication and introduces
authorization has no safe rollback.

## Outline of work

### Schema and data

- Supabase project; mirror schema v8 into Postgres — same table and column names,
  `int` PKs preserved. No UUID migration; nothing needs it.
- `profiles` table: `id UUID FK → auth.users`, `display_name`,
  `role TEXT CHECK (role IN ('owner','manager','staff'))`.
- One-time import: `tool/import_to_supabase.dart`, reading the existing backup JSON
  export. Verify row counts **and financial totals** per table before and after.
  This is the moment `backup_service.dart` either pays off or bites — if it has drifted
  from the schema across docs 03, 05, 09 and 11, the migration has no clean source.

### Auth and authorization

- **Disable public signup** in Supabase Auth settings. Users are created by hand in the
  dashboard. This is the closed-user-group requirement and it must be enforced
  server-side, not in the app.
- RLS policies, per role:

| | orders / lines | billing + prices | ledger + payments | counter stock | kitchen list | masters + settings |
|---|---|---|---|---|---|---|
| **owner** | RW | RW | RW | RW | R | RW |
| **manager** | RW | RW | RW | RW | R | — |
| **staff** | — | — | — | RW | R | — |

- `lib/screens/auth/login_screen.dart` — email + password. No signup link, no in-app
  password reset; the owner resets from the Supabase dashboard.
- `lib/providers/session_provider.dart` — doc 10b's hardcoded `owner` is replaced by the
  real session role. Every gate written in docs 10–12 becomes live **with no screen
  changes**. If a screen has to change here, the gating was written wrong.

### Data layer port

- Replace each DAO with a Supabase query module. **Provider signatures do not change** —
  screens stay untouched. Drift stays in `pubspec.yaml` until every DAO is ported,
  then goes.
- Every screen gains an explicit loading state and an explicit **offline** state.
  Offline means an inline banner with a retry, never a silent empty list. A spinner
  with no timeout is a bug, not a state.

## The known risk, stated plainly

Order entry at 5 a.m. in a basement kitchen with no signal **fails outright** under
online-only. That is the accepted cost of the decision.

The cheap mitigation, if it bites in practice: a draft buffer on the order-entry
screen only — hold unsaved quantities in `shared_preferences` (already a dependency)
and flush on reconnect. Roughly 60 lines, one screen, no sync engine, no conflict
resolution. **Not built now.** Built the week it first hurts.

## Success criteria

- [ ] Row counts and financial totals match **exactly**, local vs Supabase, on the full
      imported dataset.
- [ ] A staff login cannot read prices, revenue or ledger — verified by querying those
      tables directly with the staff JWT, not by checking that the UI hides them.
- [ ] Signup is impossible from the app **and** from a raw API call.
- [ ] Two devices editing different shops' orders concurrently both persist.
- [ ] Killing the network mid-order surfaces a visible error, never silent data loss.
- [ ] Every screen has a distinguishable loading state and offline state.
- [ ] No screen file changed as part of the DAO port.

## Notes

- The Supabase **anon key ships inside the APK**. That is normal and expected — RLS is
  the security boundary, not the key. The `service_role` key must never appear in the
  repo, in CI, or in the app.
- Keep a Drift-backed build runnable until the port is fully verified. The ability to
  fall back is worth the branch maintenance.
