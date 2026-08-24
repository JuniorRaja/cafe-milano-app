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

**Rewrite history with `git filter-repo`, keep the repository public.** Chosen
2026-08-23 over the alternatives (remove-going-forward, going private, or both).

Rationale: the repo has 0 forks and 0 stars, so the rewrite's blast radius is
effectively zero, and staying public is what keeps [doc 01](01-in-app-update.md)'s
token-free update check and the [doc 13](13-distribution-docs.md) download page
viable. Do not re-litigate this.

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

### Purge the history

Do this **after** the code changes above are merged to `master`, so the rewrite is
done once against final content.

- [ ] Confirm no other branch needs the file. At time of writing the only branches
      are `master` and `claude/shop-ledger-payments-vaavtt`.
- [ ] Take a full local backup of the repo before starting. This step is not
      reversible from the remote once force-pushed.
- [ ] `git filter-repo --invert-paths --path docs/cafe-milano-backup-20260708-224812.json`
      Verify with `git log --all --oneline -- docs/cafe-milano-backup-20260708-224812.json`
      returning nothing.
- [ ] Force-push `master`. Re-clone locally afterwards — `filter-repo` rewrites every
      commit SHA, so the existing working copy is no longer usable against the remote.
- [ ] Existing release **tags** point at rewritten SHAs. Verify the Releases page
      still resolves and the published APK assets still download; re-push tags if not.
      The APKs themselves are unaffected — they are uploaded binaries, not git objects.
- [ ] After GitHub has garbage-collected, re-check the raw URL returns 404. This can
      lag; if it persists, GitHub Support can force GC on request.
- [ ] Treat the exposed data as having been public since 2026-07-08. Whether the
      shops' phone numbers warrant telling anyone is a judgement call — flagging it
      here so the decision is deliberate rather than skipped.

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
- [ ] `git log --all -- docs/cafe-milano-backup-20260708-224812.json` is empty.
- [ ] The raw GitHub URL returns 404.
- [ ] The Releases page still lists prior releases with working APK downloads.
