# 01 — In-app update check

| | |
|---|---|
| **Target version** | `1.6.0+6` |
| **Type** | Feature |
| **Schema** | No change |
| **Ships with** | [02 — Shipped-data cleanup](02-shipped-data-fix.md) |
| **Status** | Ready |

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

- [ ] `pubspec.yaml` — add `url_launcher: ^6.3.1`. One new dependency, no native
      config needed on Android for `https` intents.
- [ ] `lib/services/update_service.dart` — new.
  - `Future<UpdateInfo?> checkForUpdate()` — GET the latest-release endpoint with a
    **10-second timeout**. Parse `tag_name`, `body` (release notes), `html_url`, and
    the `browser_download_url` of the first asset whose name ends in `.apk`.
  - Return `null` when the remote build number is less than or equal to the
    installed one. Return `null` on **any** failure — no network, timeout, non-200,
    malformed JSON, no APK asset attached. A failed update check must be invisible;
    it is never an error the user needs to see.
  - Do not add an HTTP client dependency. `dart:io` `HttpClient` is sufficient for
    one GET, and the app already carries enough packages.
- [ ] `lib/services/update_service.dart` — throttle with `shared_preferences`
      (already a dependency): store `lastUpdateCheckAt`, skip if checked within 24h.
      Store `dismissedBuild` so a build the user dismissed is never offered again.
- [ ] `lib/providers/update_provider.dart` — new. A `FutureProvider<UpdateInfo?>`
      wrapping the service. Must not block any screen's first paint.
- [ ] `lib/app.dart` — fire the check once after first frame, not during
      `main()`. `main()` currently `await`s database seeding before `runApp`; adding
      a network round-trip there would put a variable, connection-dependent delay in
      front of the splash screen.
- [ ] `lib/widgets/update_banner.dart` — new. A dismissible banner or small dialog:
      version, release notes from `body`, **Download** → `launchUrl` on the APK URL
      with `LaunchMode.externalApplication`, and **Later** → records `dismissedBuild`.
- [ ] Settings — a manual **Check for updates** row showing the installed version,
      that bypasses the 24h throttle and reports "you're up to date" when there is
      nothing new. This is the path that works when the automatic check has silently
      failed, so it must give explicit feedback in every case.

## Notes and constraints

- **The app cannot install the APK itself.** Android requires the
  `REQUEST_INSTALL_PACKAGES` permission for that, and it puts the app in a Play
  Store policy category worth avoiding even though this app is side-loaded. Handing
  the URL to the browser and letting the system installer take over is the correct
  scope. The user taps through the normal "install from unknown sources" flow.
- Do not add a "force update" mode. Single-user, offline-capable app; a blocking
  update gate can only ever hurt.
- Rate limit: unauthenticated `api.github.com` allows 60 requests/hour/IP. At one
  check per day this is not a concern, but it is why the 24h throttle exists rather
  than checking on every launch.

## Success criteria

- [ ] With `1.6.0+6` installed and `v1.6.0-6` the latest release, no banner appears.
- [ ] With `1.5.0+5` installed and `v1.6.0-6` published, the banner appears and
      **Download** opens the browser on the `MilanoOrders-v1.6.0-6.apk` asset.
- [ ] Airplane mode: app launches normally, no error surfaces, no visible delay
      attributable to the update check.
- [ ] The check does not delay first paint — cold-start time is unchanged with the
      network unreachable *and* with a slow connection.
- [ ] Dismissing an update stops it being offered again on subsequent launches;
      a *newer* build than the dismissed one is still offered.
- [ ] Manual **Check for updates** in Settings reports a clear result in all three
      cases: update available, up to date, and check failed.
- [ ] Two launches within 24 hours produce exactly one network request.
