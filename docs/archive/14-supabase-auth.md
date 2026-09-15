# 14 — Supabase, auth & biometric unlock

| | |
|---|---|
| **Target version** | `2.0.0+19` |
| **Type** | Major |
| **Schema** | Port v6 to Postgres |
| **Requires** | [14a — Repository seam](14a-repository-seam.md), and everything above it shipped and stable on Drift |
| **Followed by** | [15](15-auto-order-suggestions.md) · [16](16-weekly-ai-report.md) · [17](17-white-label.md) |
| **Status** | **Outline** — expand into `14b`, `14c`, … before starting |

## Why

The big one, and the reason `2.0.0` is reserved. Everything above ships on Drift first,
then the data layer swaps underneath **unchanged Riverpod providers** — which is only
possible because [14a](14a-repository-seam.md) put a seam there first.

What this buys: the data stops living on one phone. A lost or wiped device stops being a
total loss, the owner can open the app on a second device, and
[16](16-weekly-ai-report.md) becomes possible at all, because something server-side can
read the data on a schedule.

## Decisions

Taken 2026-08-28, replacing the 2026-08-19 set.

| Question | Decision | What it replaces |
|---|---|---|
| Backend | Supabase — **Postgres, PostgREST and Storage**, online-only, no offline sync layer | unchanged |
| Auth | **Supabase Auth, with public signup disabled.** Email + password. The account is created by hand in the dashboard | replaces "no GoTrue, mint our own JWT" |
| Roles | **None. One user, full access** | replaces the three-tier owner / manager / staff matrix |
| Device unlock | **Biometric gate on app open**, local only | new |
| Sequencing | UX and features first on Drift, Supabase last | unchanged |

### Why Supabase Auth rather than a custom credential check

The requirement was a closed user group with a predefined username and password, and no
self-serve signup. **That is exactly Supabase Auth with signup disabled** — accounts are
created by hand in the dashboard, there is no signup route, and the login screen carries
no "create account" link.

The alternative — checking credentials against an app table and minting a JWT ourselves —
requires the project JWT secret. Either it ships inside the APK, where anyone who unzips
the file can mint tokens forever and cannot be locked out without rotating the whole
project, or it lives in an Edge Function that has to be written, deployed and maintained
purely to reimplement what GoTrue already does correctly. Neither buys anything the
dashboard toggle does not.

Using Supabase Auth also means refresh-token rotation, session persistence and secure
storage are handled by `supabase_flutter` rather than by hand. That is the part of an
auth system that is easy to get subtly wrong.

### Why no roles

With counter stock dropped there is no longer a job in the app that belongs to someone
other than the owner. A three-tier matrix would be six resource groups of RLS policy
protecting one person from themselves.

RLS is still on, and it still matters — it is what stops the shipped anon key being a
public read of the whole business. It is just a **binary door**: `authenticated` may read
and write everything, `anon` may do nothing.

**The honest consequence, stated once:** whoever has the password has everything —
prices, revenue, every shop's ledger. There is no partial access and no audit trail of
who did what. That is acceptable for one user and it is the thing to revisit first if a
second person ever gets a login. Adding roles later needs one `profiles` table and a
policy rewrite; **it needs no schema change and no screen change**, which is why deferring
it costs nothing.

## Outline of work

Split this into `14b`, `14c`, … before starting. A single release that changes the
storage engine, adds authentication and rewrites every provider has no safe rollback.
The suggested cut: **schema + import**, then **auth + session**, then **the port itself**.

### Schema and data

- Supabase project. Mirror schema **v6** into Postgres — same table and column names,
  `int` PKs preserved. No UUID migration; nothing needs it.
- The chain is frozen at v6 (see [roadmap](../roadmap.md)), so this is a port of a fixed
  target rather than a moving one. That is a meaningful reduction in risk from the
  original plan, which was porting v8 with two more migrations still to write.
- One-time import: `tool/import_to_supabase.dart`, reading the existing backup JSON
  export. Verify row counts **and financial totals** per table, before and after.
- This is the moment `backup_service.dart` either pays off or bites. It has been the
  standing risk in every schema doc; with the chain frozen it should now be exact.
  **Verify that before trusting it as the migration source** — export, re-import into a
  fresh local install, and diff, before pointing it at Postgres.

### Auth and session

- **Disable public signup** in the Supabase Auth settings. Enforced server-side, in the
  dashboard, not in the app. Verify with a raw API call, not by looking at the UI.
- Create the owner's account by hand. One account.
- `lib/screens/auth/login_screen.dart` — email + password. No signup link, no in-app
  password reset. The owner resets from the dashboard.
- `lib/providers/session_provider.dart` — wraps `supabase.auth.onAuthStateChange`. The
  router redirects to `/login` when there is no session and away from it when there is.
- Session persistence is `supabase_flutter`'s job. Do not hand-roll token storage.

### Biometric unlock

- `local_auth` gates **app open**, once a session already exists. Fingerprint or face,
  falling back to the device PIN.
- **Be precise about what this is.** Biometric is a local convenience gate over an
  already-valid session. It is not a second authentication factor and Supabase never sees
  it. Someone with an unlocked phone and the refresh token in storage has the data
  regardless — the gate raises the cost of a glance over the shoulder, not of a
  compromised device.
- Triggered on cold start and on `AppLifecycleState.resumed` after a timeout the owner
  can set (default: immediately). The `AppLifecycleListener` that
  [10b](10b-navigation.md) adds is the hook.
- Always offer a way past a failed biometric read — a scanner that stops working must not
  lock the owner out of the day's orders at 5 a.m. Falling back to the account password
  is the correct escape hatch.

### Storage

- `business_info.logoPath` is a local file path today. It becomes a Supabase Storage
  object, with the path stored instead of the device path. One bucket, private, read
  through a signed URL.
- Nothing else in the app holds a file. PDF statements are generated on demand and shared
  immediately — they do not need to be stored, and storing them would create a retention
  question nobody has asked for.

### The data layer port — the actual work

- Replace each repository body ([14a](14a-repository-seam.md)) with a PostgREST call.
  **Provider signatures do not change. Screens stay untouched.** Drift stays in
  `pubspec.yaml` until every repository is ported, then goes.
- **The hard part is the streams, and it should be planned for explicitly.** The UI is
  built on **18 `StreamProvider`s** fed by Drift `watch*` queries that re-emit on any
  local write. Postgres has no equivalent for free. Two options, and the choice belongs
  in `14c` rather than here:
  - **Supabase Realtime** channels per table, mapped back into the same `Stream` shape.
    Closest to current behaviour; costs a subscription budget and a reconnect story.
  - **Fetch plus explicit invalidation** — the provider re-reads after any write through
    the same repository. Simpler, no sockets, and it is what a single-user app actually
    needs, because the only writer is this device.

  For one user, the second is almost certainly right and the first is the reflex answer.
  Decide it deliberately.
- The **15 `FutureProvider`s** port straight across.
- Every screen gains an explicit loading state and an explicit **offline** state. Offline
  means an inline banner with a retry, never a silent empty list. A spinner with no
  timeout is a bug, not a state. [10c](10c-screen-restyle.md)'s `AppErrorView` is what
  these render.

## The known risk, stated plainly

Order entry at 5 a.m. in a basement kitchen with no signal **fails outright** under
online-only. That is the accepted cost of the decision.

The cheap mitigation, if it bites in practice: a draft buffer on the order-entry screen
only — hold unsaved quantities in `shared_preferences` (already a dependency) and flush on
reconnect. Roughly 60 lines, one screen, no sync engine, no conflict resolution.
**Not built now.** Built the week it first hurts.

## Success criteria

- [ ] Row counts and financial totals match **exactly**, local vs Supabase, on the full
      imported dataset.
- [ ] Signup is impossible from the app **and** from a raw API call.
- [ ] Querying any table with only the anon key returns nothing. Verified with `curl`,
      not by checking that the UI asks for a login.
- [ ] Killing the network mid-order surfaces a visible error, never silent data loss.
- [ ] Every screen has a distinguishable loading state and offline state.
- [ ] **No screen file changed as part of the port.** This is the criterion
      [14a](14a-repository-seam.md) exists to make achievable.
- [ ] Biometric failure still lets the owner in with the account password.
- [ ] A fresh install on a second device signs in and shows the same data.
- [ ] The app opens, and the day's orders can be entered, with the Drift build fully
      removed from `pubspec.yaml`.

## Notes

- The Supabase **anon key ships inside the APK**. That is normal and expected — RLS is
  the security boundary, not the key. The `service_role` key must never appear in the
  repo, in CI, or in the app.
- Keep a Drift-backed build runnable until the port is fully verified. `1.13.1+18` is
  that fallback: the last fully stable local-only version. The ability to fall back is
  worth the branch maintenance.
- **Do the import twice.** Once as a rehearsal against a throwaway project, then for real
  on the day. The rehearsal is where `backup_service.dart` gets caught being wrong, and
  it is much cheaper to find that on a project nobody depends on.
