# 02 — Shipped-data cleanup

| | |
|---|---|
| **Target version** | `1.6.0+6` |
| **Type** | Fix |
| **Schema** | No change |
| **Ships with** | [01 — In-app update check](01-in-app-update.md) |
| **Status** | Ready |

## Why

Three separate problems about *what data leaves the developer's machine*. None of
them touch the live database — `lib/database/app_database.dart:67-69` opens
`milano_orders.db` in the phone's application-documents directory, and that file
never leaves the device. That part is correct and stays as it is.

### 1. A real data snapshot is committed to a public repo

`docs/cafe-milano-backup-20260708-224812.json` — 1,767,674 bytes, added at commit
`9c610fd`, present on `master`. It is a real export taken through the app's own
Backup & Restore feature on 2026-07-08, containing:

| | |
|---|---|
| 18 shops | real names, areas, **phone numbers** |
| 28 products | full catalogue |
| 212 shop prices | the complete per-shop price matrix |
| 329 standing orders | |
| 95 orders / 506 lines | real trading history |
| 1 embedded image | base64 |

The repository is public (`"private": false`), so this is readable without
authentication at
`raw.githubusercontent.com/JuniorRaja/cafe-milano-app/<sha>/docs/cafe-milano-backup-20260708-224812.json`.

Using it as dev seed data was reasonable — a fresh `flutter run` comes up with a
realistic dataset instead of two dummy shops. Committing it to a public repo was
the mistake.

### 2. It ships inside every APK

`pubspec.yaml:44` declares it under `assets:`. Flutter bundles declared assets
**unconditionally** — the `kDebugMode` guard at `lib/main.dart:15` only stops it
being *read* in release builds, not packaged. Every APK handed out over WhatsApp
contains the file, extractable by unzipping. It is also ~1.7 MB of the APK.

### 3. Release builds seed fabricated demo shops

`lib/main.dart:15-19` — in release, `seedDatabase(db)` runs, inserting **"Hotel Raj"**
and **"Star Bakery"** with six dummy products (`lib/database/seed_data.dart:17+`).
It is guarded by "skip if any shop exists", so it only fires on a clean install —
which is precisely the new-phone and restore-from-backup case. A first-time user
opens the app to two fictional shops.

## Decision taken

**Remove the file going forward, keep the repository public, skip the history
rewrite.** Superseded 2026-08-24 — originally planned to rewrite history with
`git filter-repo`, decided against it as too much effort for the payoff.

Rationale: the repo has 0 forks and 0 stars, so staying public is what keeps
[doc 01](01-in-app-update.md)'s token-free update check and the
[doc 13](13-distribution-docs.md) download page viable. `git rm` stops the file
from shipping and from appearing in the repo's current tree / `git log`, but the
old commit (`9c610fd`) and its raw GitHub URL remain reachable indefinitely —
this is accepted, not a gap to close later. Treat the backup's contents (shop
names, areas, phone numbers, trading history) as having been public since
2026-07-08 regardless of what the repo looks like today.

## Action items

### Stop it shipping

- [x] `pubspec.yaml` — delete line 44, the
      `- docs/cafe-milano-backup-20260708-224812.json` asset entry. Leave
      `mobile-app-logo-trasnsp.png` and `bg-vector.png`; both are genuinely used
      (`lib/app.dart:30`, `lib/screens/splash/splash_screen.dart:53`,
      `lib/widgets/app_background.dart:16`).
- [x] `lib/database/dev_seed.dart` — stop loading from `rootBundle`. Read from a
      **git-ignored local path** instead, and no-op cleanly when the file is absent
      so a fresh clone still runs. Suggested: `dev/seed.json`, with `/dev/` added
      to `.gitignore`.
- [x] `.gitignore` — add `/dev/` and a `docs/*backup*.json` guard so an exported
      backup can never be committed into `docs/` again by reflex.
- [x] `README.md` — one short section: to seed realistic dev data, export a backup
      from your own device and drop it at `dev/seed.json`. Nobody will remember this
      otherwise.

### Fix the release seed

- [x] `lib/main.dart` — remove the `seedDatabase(db)` call from the release branch.
      A fresh install must start **empty**, with no fabricated shops or products.
- [x] Keep `seedDefaultCategories(db)` running on fresh installs — the nine default
      categories are real app scaffolding, not fake business data.
- [x] Confirm the empty-state UI is not embarrassing on a genuinely empty database.
      Home, Kitchen, Billing and Dashboard all need to read as "nothing here yet",
      not as a broken screen. Add empty states where missing — this is the first
      thing a new install shows, and until now nobody has ever seen it.
      Kitchen, Billing and each Dashboard card already had one; Home
      (`lib/screens/home/home_shops_screen.dart`) was the one gap — added a
      matching icon+text empty state for zero shops.
- [x] `lib/database/seed_data.dart` — keep `seedDatabase` in the tree for tests and
      debug use, but it must no longer be reachable from a release build.

### Purge the history — skipped

Decided 2026-08-24: not doing the `git filter-repo` rewrite. Too much effort
(install tooling, rewrite all SHAs from `9c610fd` onward, force-push, re-push
tags, re-verify Releases page and raw-URL 404) for the marginal benefit, given
0 forks/0 stars and the data having already been public for 7 weeks regardless.

- [x] File removed from the working tree going forward (`git rm`) — see above.
- [ ] Not doing: history rewrite, force-push, tag re-push, raw-URL 404 check.
- [ ] Not doing: notifying anyone about the phone-number exposure — revisit if
      that changes.

## Success criteria

- [ ] `unzip -l` on a release APK shows no `*.json` backup asset.
- [ ] Release APK is roughly 1.7 MB smaller than `1.5.0+5`. Record the actual
      before/after figures — this is the only measured size claim in the roadmap.
- [ ] A clean install of the release build opens with **zero** shops and zero
      products, the nine default categories present, and every tab showing a sensible
      empty state.
- [ ] Restoring a backup into that clean install produces the correct data.
- [ ] `flutter run` in debug with no `dev/seed.json` starts cleanly and does not throw.
- [ ] `flutter run` in debug **with** `dev/seed.json` present seeds as before.
- [ ] ~~`git log --all -- docs/cafe-milano-backup-20260708-224812.json` is empty.~~
      N/A — history rewrite skipped, the old commit stays in `git log --all`.
- [ ] ~~The raw GitHub URL returns 404.~~ N/A — same reason.
- [ ] The Releases page still lists prior releases with working APK downloads.
