# Milano Orders — Roadmap

> Last updated: 2026-09-15
> Shipped version: **1.12.0+16** · schema v6 (frozen)

This is the index. Each feature has its own plan in `docs/features/`, sized to ship as
one release. Build it, bump `pubspec.yaml`, push to `master`, let CI cut the release,
move to the next.

Three files carry the working knowledge: [`AGENTS.md`](../AGENTS.md) (rules — read first),
[`docs/architecture.md`](architecture.md) (facts), [`docs/development.md`](development.md)
(procedures). Update them in the same commit as any change they describe.

Old plans live in `docs/archive/`. History only.

---

## What changed — 2026-09-14

The owner cut the cloud from the plan. Four decisions:

| Decision | Effect |
|---|---|
| **No backend. No login.** The app stays local-first on SQLite (Drift) with one user and no auth | [14 — Supabase](archive/14-supabase-auth.md) is **dropped** and archived. [14a — repository seam](archive/14a-repository-seam.md) is **dropped** with it — it existed only to make that port safe |
| **White-label is next after the dashboard tabs**, and it works without a server | [17](features/17-white-label.md) rewritten: config comes from a per-business file compiled into the build, plus a settings screen for the words and the currency. No config table, no tenant database |
| **The weekly AI report runs on the phone**, with the owner's own Anthropic API key pasted into Settings | [16](features/16-weekly-ai-report.md) rewritten: no Edge Function, no cron, no email. The owner taps a button and gets the report |
| **Update flow finished right after white-label**, because both touch the same release pipeline | [13](features/13-distribution-docs.md) rewritten: per-business builds, per-business update check, one download page |
| **Code goes private; downloads move to a public downloads-only repo** (2026-09-15) | [13](features/13-distribution-docs.md): CI publishes to `orderflow-releases` with a token scoped to that repo. APKs are named by a random `DOWNLOAD_ID`, never a business name. **No second business is onboarded until this is done** |

**Parked:** [15 — auto order suggestions](features/15-auto-order-suggestions.md). Works
fine locally, no decision taken on when. Not in the sequence below.

### What was dropped

| Doc | Why |
|---|---|
| [06 — Ledger manual allocation](features/06-ledger-manual-allocation.md) | FIFO auto-allocation covers the real cases |
| [09 — Exclude shops from grand total](features/09-shop-exclusion.md) | Owner's call, 2026-08-27 |
| [11 — Counter stock](features/11-counter-stock.md) | Owner's call, 2026-08-28. This app does not count stock |
| [14 — Supabase, auth](archive/14-supabase-auth.md) | Owner's call, 2026-09-14. Local-first, single user |
| [14a — Repository seam](archive/14a-repository-seam.md) | Dropped with 14. Work with no reader |

Docs stay as the record of the decision. Do not resurrect one without adding a row here.

---

## Release sequence

| # | Feature | Version | Type | Status |
|---|---|---|---|---|
| [01](features/01-in-app-update.md) | In-app update check | `1.6.0+6` | feature | Done |
| [02](features/02-shipped-data-fix.md) | Shipped-data cleanup | `1.6.0+6` | fix | Done |
| [03](features/03-db-integrity.md) | FK enforcement + indexes | `1.6.1+7` | fix | Done |
| [04](features/04-dashboard-performance.md) | Dashboard query cleanup | `1.6.2+8` | fix | Done |
| [05](features/05-ledger-foundation.md) | Ledger — payments & balances | `1.7.0+9` | feature | Done |
| [07](features/07-ledger-statements.md) | Ledger — statements & outstanding | `1.8.0+10` | feature | Done |
| [08](features/08-order-entry-swipe.md) | Digit-wheel quantity entry | `1.9.0+11` | feature | Done |
| — | Backup/import schema compatibility | `1.9.1+12` | fix | Done |
| — | Stop seeding default categories | `1.9.2+13` | fix | Done |
| [10a](features/10a-design-system.md) + [18](features/18-foundation-guardrails.md) | New look, faster, quantities never lost | `1.10.0+14` | feature | Done |
| [10b](features/10b-navigation.md) + [device pass](features/10b-device-pass.md) | Everything reachable in 2 taps | `1.11.0+15` | feature | Done |
| [10c](features/10c-screen-restyle.md) | Every screen rebuilt, real error messages | `1.12.0+16` | feature | Done |
| [12](features/12-dashboard-tabs.md) | Dashboard in tabs, updating live | `1.13.0+17` | feature | **Code on `master`, release not cut** |
| [17](features/17-white-label.md) | Rebuild the app for another business | `2.0.0+18` | major | Ready |
| [13](features/13-distribution-docs.md) | Private code, public downloads, updates that pick the right build | `2.1.0+19` | feature | Ready |
| [16](features/16-weekly-ai-report.md) | Weekly report written by Claude, on the phone | `2.2.0+20` | feature | Ready |

### The three releases left, in one sentence each

- **`2.0.0+18` — white-label.** The product becomes **OrderFlow**, with neutral words —
  "customer" instead of "shop", "production" instead of "kitchen". One config file per
  business sets its own name, logo, colour, words and currency.
  `flutter build apk --flavor acme` produces that business's app. Milano becomes
  `businesses/milano.json`, keeps its package id, and looks exactly as it does today.
  **Ships with only `milano.json` and the fake `example.json`** — the code repo is still
  public at this point.
- **`2.1.0+19` — private code, public downloads.** The code repo goes private. CI
  publishes every business's APK to one release in the public `orderflow-releases` repo,
  named `OrderFlow-<DOWNLOAD_ID>-<tag>.apk`. All businesses share one version number. The
  update check reads the public repo and matches its own ID. The download page lives there
  too, filtered by `?b=<id>`. Migration order: ship to both repos → confirm on Milano's
  phone → only then make the code repo private.
- **`2.2.0+20` — weekly AI report.** The owner pastes their own Anthropic API key into
  Settings and taps *Generate*. The app sends last week's totals and gets back a short
  written report. Saved on the device, shareable as text.

---

## Branching

**`master` is production.** It only receives finished releases.

- Never commit to `master` directly.
- One branch per release: `release/2.0.0-white-label`.
- Merge only when the readiness gate passes. The merge **is** the release — CI reacts to
  the version change on `master`.
- Commit as often as you like. Bump the version once, at the end.

## What a release must be

Every release leaves the app fully usable. No half-migrated state. If the work cannot
land whole, it is not one release.

Every release can be described in one sentence the owner cares about. "Internal cleanup"
is too thin — merge it into the release before or after.

## The readiness gate

Run all eight before every merge to `master`.

1. Every **Success criterion** in the feature doc is ticked.
2. `flutter test` — green.
3. `flutter analyze` — clean.
4. `./tool/check_tokens.sh` — passes.
5. The APK is installed on the real phone.
6. Smoke pass on that phone: order entry → kitchen → billing → ledger → record a payment
   → export a statement.
7. A backup exported from the **previous** version restores into this one.
8. `version:` in `pubspec.yaml` is bumped.

Step 7 is the one that gets skipped and the one that corrupts real data. Do it.

## Versioning

| Change | Bump |
|---|---|
| Anything the user can see or feel | minor |
| Invisible fix, refactor or tooling | patch |
| The app can be rebuilt for another business | major (`2.0.0`) |

- Build number `+N` increments by one on every release. Never resets, never skips.
- A release with a feature and fixes takes the minor bump.
- `2.0.0` is white-label. `2.0.0` was reserved for Supabase; that is dropped, so
  white-label takes it.

## Status legend

`Ready` — can be built as written.
`Outline` — substance captured, expand before starting.
`Built` — code is green on its branch, gate not finished. Not shipped.
`Done` — shipped.
`Dropped` — decided against.

---

## Schema

**The Drift chain is frozen at v6.** No v7. Nothing in the three remaining releases adds
a table:

- White-label settings (words, currency) go in `shared_preferences`, not the database.
- Weekly reports are written as JSON files in the app documents directory.

That keeps `lib/services/backup_service.dart` stable — it round-trips exactly what exists
today and nothing more.

If a schema change ever becomes necessary again, the old rule returns: extend
`backup_service.dart` in the same commit, and run the full upgrade chain against a real
v4 install before shipping.

## Lifecycle audit

[`docs/flutter-lifecycle-audit.md`](flutter-lifecycle-audit.md) proposed six phases.
Phases 0–3 and 6 shipped inside releases `1.10.0`–`1.12.0`. Phase 4 (Riverpod
modernisation, dashboard streams) ships with [12](features/12-dashboard-tabs.md).
**Phase 5 is dropped** with doc 14a — it was the Supabase precondition.

---

## Standing risks

- **`1.13.0` was never cut.** The dashboard-tabs code is merged into `master` but
  `pubspec.yaml` still says `1.12.0+16`, so no release was published. Either cut it or
  fold the bump into `2.0.0`.
- **There is no CI gate.** `flutter analyze` and `flutter test` are run by hand, so
  steps 2 and 3 of the readiness gate are only as reliable as the person running them.
- **No performance baseline.** The `1.10.0` criteria passed on the owner's device but the
  numbers were never written down. Capture them next time the phone is out.
- **The font changed twice** — Quicksand → Raleway → Bricolage Grotesque — and the sizes
  were re-read once, in `1.12.0`. Watch for text that reads heavy.
- **Money arithmetic is thinly tested.** FIFO allocation (05) and the quantity wheel (08)
  have tests. Nothing else needs them.
- **APK is ~60 MB universal.** Split-per-ABI was rejected on purpose so nobody has to pick
  a file. No size work on guesswork — run `--analyze-size` first.
- **Design-system drift.** `tool/check_tokens.sh` is blocking as of `1.12.0`. Do not
  disable it to land something quickly.
- **The code repo is public until `2.1.0`'s migration finishes.** Until then, do not commit
  any real second business's config — anything committed while public may already be
  cloned, and making the repo private later does not undo that. After the migration, the
  public repo shows how many businesses there are, and anyone can download an APK and see
  whose it is. Names are hidden from the repo, not from the APKs. See
  [13](features/13-distribution-docs.md).
- **`RELEASES_REPO_TOKEN` expires.** When it does, releases fail in CI; phones are fine.
  The expiry date lives in `docs/development.md`.
- **The API key for the weekly report is the owner's own**, typed into the app and stored
  in app-private storage. It is never in the APK and never in the repo. See
  [16](features/16-weekly-ai-report.md).
