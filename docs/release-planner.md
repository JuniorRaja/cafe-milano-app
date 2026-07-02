## Release

- I want to release this app
- Not in playstore. Just sending the file to the user
- Reduce the final build apk size
- Github Release pipeline

## Current state (as found in repo)

- Flutter app, `pubspec.yaml` version `1.0.0+1`.
- Android `applicationId`: `com.cafemilano.cafe_milano`, `namespace`: `com.cafemilano.cafe_milano`.
- Release build type currently signs with the **debug** keystore (`android/app/build.gradle.kts`) — no real release keystore or `key.properties` exists yet.
- No `.github/workflows` directory yet — no CI/CD set up.
- Git remote: `https://github.com/JuniorRaja/cafe-milano-app.git`.

## Open questions (please answer inline below each)

1. **Signing**: Since this isn't going to the Play Store, do you want a proper release keystore anyway (recommended, so future updates can be verified/upgraded cleanly), or is signing with the debug key acceptable since it's just an APK you're handing out?
   - Answer: No, let's do production grade. So, I could also learn about an actual release.

2. **Keystore ownership**: If we create a release keystore, who holds the keystore file + passwords long-term? Do you want it committed nowhere (kept locally + as a GitHub Actions secret), or do you already have a keystore from elsewhere?
   - Answer: I will have it locally and will be stored in github action secrets

3. **Distribution mechanism**: "Sending the file to the user" — do you mean you'll manually download the APK from a GitHub Release and send it (e.g. WhatsApp/email), or should the pipeline do anything else (e.g. auto-upload to a shared link)?
   - Answer: I'd send  over whatsapp

4. **APK size reduction**: Are you fine with the standard Flutter release levers — enabling `minifyEnabled`/R8 + resource shrinking, and building **split per-ABI APKs** (arm64-v8a / armeabi-v7a / x86_64 separately, since a single "fat" APK bundles all architectures)? Since it's not Play Store (no App Bundle/dynamic delivery), split APKs is the main lever — meaning the user has to pick the right file for their device's architecture (arm64-v8a covers the vast majority of modern Android phones). Is that acceptable, or do you want one universal APK?
   - Answer: Universal, cus I ain't that expert to go with specific builds nor be able to find why something doesn't work.

5. **Versioning**: How should the pipeline decide the version number for each release — bump `pubspec.yaml` manually before tagging, or derive it from the git tag (e.g. tag `v1.1.0` → `versionName 1.1.0`)?
   - Answer: if I change the version in pubspec then it shall be considered as a release

6. **Release trigger**: Should the GitHub Release pipeline run on every push of a version tag (e.g. `v*`), on merge to `master`, or only when manually triggered (`workflow_dispatch`)?
   - Answer: As mentioned above

7. **Release notes**: Auto-generate from commit messages/PR titles, or do you want to write them by hand each time?
   - Answer: Maybe auto gen or consolidated from commit message. Also, version bump based on feat/chore/fix

## Resolved decision (Q5/Q6/Q7 conflict)

Q5/Q6 pointed to a manual version bump; Q7 pointed to fully automatic semantic-release-style bumping. These conflict, so asked directly:

- **Decision: Manual bump in `pubspec.yaml`.** You edit `version: x.y.z+n` yourself and push to `master`. The workflow detects the version changed, builds, tags, and cuts a GitHub Release for that version. Release notes are auto-generated from the commit messages since the last release (no need to hand-write them, no need for conventional-commit discipline).

## What was implemented

- `android/app/build.gradle.kts`: real release `signingConfig` read from `android/key.properties` (git-ignored). Falls back to the debug key automatically when `key.properties` is absent, so `flutter run --release` still works with zero setup on a machine without the release keystore.
- `android/app/build.gradle.kts`: `isMinifyEnabled = true` + `isShrinkResources = true` on the release build type (R8 + resource shrinking), using Flutter's default `proguard-android-optimize.txt` plus a new empty `android/app/proguard-rules.pro` for future custom keep rules if a release ever crashes from over-aggressive stripping.
- `.gitignore`: added `/android/key.properties`, `*.jks`, `*.keystore` so the keystore and its passwords can never be committed by accident.
- `android/key.properties.example`: template showing the 4 fields `key.properties` needs (`storePassword`, `keyPassword`, `keyAlias`, `storeFile`).
- `.github/workflows/release.yml`: on every push to `master`, compares `pubspec.yaml`'s `version:` line against the previous commit. If unchanged (or the tag already exists), the job no-ops. If changed, it builds a signed universal release APK, tags the commit `vX.Y.Z(-build)`, auto-generates release notes from `git log` since the last tag, and publishes a GitHub Release with the APK attached.
- Verified locally: `flutter build apk --release` succeeds with the new config (falls back to debug signing since no local keystore exists yet) — `app-release.apk`, 60.1MB, single universal file.

## One-time setup (you need to do this — I didn't touch your keystore or secrets)

1. **Generate the release keystore**, on your own machine, in a private terminal (not committed anywhere). `keytool` isn't on PATH on this machine — it ships with Android Studio's bundled JDK instead:
   ```
   "D:\AndriodStudio\jbr\bin\keytool.exe" -genkey -v -keystore milano-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias milano-upload
   ```
   Store `milano-release.jks` and the passwords you set somewhere safe (password manager). This is the **one and only** signing key for this app going forward — if you lose it, every future release becomes a "new app" as far as Android is concerned (users would have to uninstall the old APK before installing the new one).

2. **Base64-encode the keystore** so it can go into a GitHub secret. In Git Bash:
   ```
   base64 -w 0 milano-release.jks > keystore.b64
   ```
   (`certutil -encode` is a `cmd.exe`-only tool, not available from Git Bash — that's likely what "command not found" was about. Use the `base64` command above instead.)

3. **Add 4 repo secrets** at `github.com/JuniorRaja/cafe-milano-app` → Settings → Secrets and variables → Actions:
   - `RELEASE_KEYSTORE_BASE64` — contents of `keystore.b64`
   - `RELEASE_KEYSTORE_PASSWORD` — the store password you set
   - `RELEASE_KEY_ALIAS` — `milano-upload` (or whatever alias you used)
   - `RELEASE_KEY_PASSWORD` — the key password you set

4. *(Optional, for local release builds/testing on your own machine)* copy `android/key.properties.example` to `android/key.properties` and fill in the same 4 values, with `storeFile` as the absolute path to your `.jks` file. This file is git-ignored.

## How to cut a release (ongoing)

1. Bump `version:` in `pubspec.yaml` (e.g. `1.0.0+1` → `1.0.1+2`).
2. Commit and push to `master`.
3. GitHub Actions builds the signed APK, tags the commit (`v1.0.1-2`), and publishes a GitHub Release automatically — no manual trigger needed.
4. Go to the repo's Releases page, download `MilanoOrders-v1.0.1-2.apk` (named with the app + version, not the generic `app-release.apk`), send it over WhatsApp.

