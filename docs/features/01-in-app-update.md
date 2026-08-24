# 01 — In-app update check

| | |
|---|---|
| **Target version** | `1.6.0+6` |
| **Type** | Feature |
| **Schema** | No change |
| **Ships with** | [02 — Shipped-data cleanup](02-shipped-data-fix.md) |
| **Status** | Done |

## Why

Every release today ends with manually downloading an APK from the Releases page
and sending it over WhatsApp. That is the bottleneck on shipping anything
frequently — and this roadmap is built on shipping frequently. Until the app can
tell the user a new build exists and hand them the download, every later feature
in this roadmap arrives by hand.

Everything needed is already in place:

- `.github/workflows/release.yml` publishes a tagged GitHub Release with the APK
  attached on every `pubspec.yaml` version bump.
- The repo is public, so `api.github.com` release lookups need **no token** — which
  matters, because a token could not be shipped safely inside an APK.
- `package_info_plus` is already a dependency, so the installed version is readable.

The only missing piece is `url_launcher`.

## Ground truth from the release pipeline

Read these off `release.yml` — the update check must match them exactly:

- Tag format is `v{version}` with `+` replaced by `-`. So `1.6.0+6` → tag **`v1.6.0-6`**.
- The APK asset is named **`MilanoOrders-v1.6.0-6.apk`**.
- Latest release endpoint:
  `https://api.github.com/repos/JuniorRaja/cafe-milano-app/releases/latest`

**Compare on build number, not on the version string.** `roadmap.md` mandates that
`+N` increments by one on every release and never resets — that makes it a clean
monotonic integer, whereas comparing `1.10.0` against `1.9.0` as strings gets it
wrong. Parse the tag as `v{semver}-{build}`, take the trailing integer, compare
against `PackageInfo.buildNumber`. Show the semver to the user; decide with the build.

## Action items

- [x] `pubspec.yaml` — add `url_launcher: ^6.3.1`. Also needs an
      `android.intent.action.VIEW` / `https` entry in `<queries>` in
      `AndroidManifest.xml` — Android 11+ package-visibility rules hide the
      browser from `launchUrl` otherwise, contrary to what this doc originally
      assumed.
- [x] `lib/services/update_service.dart` — new.
  - `Future<UpdateInfo?> checkForUpdate(int installedBuild)` — GET the
    latest-release endpoint with a **10-second timeout**. Parses `tag_name`,
    `body` (release notes), and the `browser_download_url` of the first asset
    whose name ends in `.apk`. (`html_url` was dropped — nothing in the UI
    links to the GitHub release page.)
  - Returns `null` when the remote build number is less than or equal to the
    installed one (up to date). **Throws** `UpdateCheckException` on any
    failure — no network, timeout, non-200, malformed JSON, no APK asset
    attached — with a message tailored to each case, so the Settings row can
    show "check failed" instead of silently reporting up to date.
- [x] Settings — a manual **Check for updates** row in `profile_screen.dart`
      (the Settings tab) showing the installed version. Tapping it calls
      `checkForUpdate()` directly (spinner in the row's trailing slot while
      busy) and shows one of three `AlertDialog`s: update available (with
      **Download** → `launchUrl` on the APK URL, `LaunchMode.externalApplication`),
      up to date, or check failed with the specific error message.

## Notes and constraints

- **The app cannot install the APK itself.** Android requires the
  `REQUEST_INSTALL_PACKAGES` permission for that, and it puts the app in a Play
  Store policy category worth avoiding even though this app is side-loaded. Handing
  the URL to the browser and letting the system installer take over is the correct
  scope. The user taps through the normal "install from unknown sources" flow.
- Do not add a "force update" mode. Single-user, offline-capable app; a blocking
  update gate can only ever hurt.
- Rate limit: unauthenticated `api.github.com` allows 60 requests/hour/IP. A
  manual, user-initiated check is nowhere near that.
- No launch-time check, no throttle, no dismissed-build tracking — checking is
  always an explicit tap in Settings, so there is nothing to silently retry or
  suppress.

## Success criteria

- [ ] With `1.6.0+6` installed, tapping **Check for updates** reports up to date.
- [ ] With `1.5.0+5` installed and `v1.6.0-6` published, tapping **Check for
      updates** shows the new version and release notes, and **Download** opens
      the browser on the `MilanoOrders-v1.6.0-6.apk` asset.
- [ ] Airplane mode: tapping **Check for updates** reports a check failure, no
      crash or unhandled error.
- [ ] Cold-start time is unaffected — nothing runs until the user opens
      Settings and taps the row.
