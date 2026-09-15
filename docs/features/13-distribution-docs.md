# 13 — Private code, public downloads

| | |
|---|---|
| **Target version** | `2.1.0+19` |
| **Type** | Feature |
| **Schema** | No change |
| **Requires** | [17](17-white-label.md) for the flavors and `businesses/<slug>.json` |
| **Extends** | [01](01-in-app-update.md) — same release lookup, new repo, one more filter |
| **Blocks** | **Onboarding any second business.** No real business config is committed until this is done and the code repo is private |
| **Status** | Ready |

## What this is

Today one public repo holds the code, the releases and the update feed. With several
businesses that makes every customer's name, config and commit history public.

This release splits it in two:

| Repo | Visibility | Holds |
|---|---|---|
| `JuniorRaja/cafe-milano-app` | **Private** (after the migration below) | Code, `businesses/*.json`, CI, signing secrets |
| `JuniorRaja/orderflow-releases` | **Public** | Releases with APKs, `index.html`, a one-line `README.md`. Nothing else |

The app reads the public repo with no token, exactly as [doc 01](01-in-app-update.md)
does today. CI in the private repo writes to the public one with a token that never leaves
CI.

## How it works with three businesses

Say Milano, Acme Sweets and Daily Dairy all run the app. Each has a random `DOWNLOAD_ID`
in its business file:

```
businesses/milano.json   DOWNLOAD_ID = 7c1e09a4b2f3
businesses/acme.json     DOWNLOAD_ID = e5d2a87c0b19
businesses/dairy.json    DOWNLOAD_ID = 3f9a2c1d7e4b
```

1. You fix a bug and bump `pubspec.yaml` to `2.1.1+20`. Push to `master` in the private
   repo.
2. CI builds three APKs from the same code and publishes one release, `v2.1.1-20`, to
   `orderflow-releases`:

   ```
   v2.1.1-20
     OrderFlow-7c1e09a4b2f3-v2.1.1-20.apk
     OrderFlow-e5d2a87c0b19-v2.1.1-20.apk
     OrderFlow-3f9a2c1d7e4b-v2.1.1-20.apk
   ```

3. On Acme's phone, *Check for updates* reads `releases/latest` from `orderflow-releases`,
   sees build 20 is newer than its installed 19, and offers **only**
   `OrderFlow-e5d2a87c0b19-v2.1.1-20.apk`.
4. Milano's and Daily Dairy's phones do the same, each matching their own ID.
5. A new business gets its first install from the download page,
   `…/orderflow-releases/?b=<their id>`. Every update after that is in-app.

What that means, agreed on 2026-09-15:

- **Every business shares one version number.** A fix for Acme also gives Milano and
  Daily Dairy a new version with nothing in it for them. One product, several configs.
  Per-business version numbers would need per-business feeds and would break
  `releases/latest`. Not worth it.
- **The update check never offers another business's APK; one installed by hand is a
  separate app with an empty database.**
- **Nobody is forced to update.** The check is a manual tap, per doc 01.
- **Release notes are the same for everyone**, and deliberately bland — see below.

## One release, many APKs

One tag per version, as today. Each business's APK is a separate **asset** on that
release. Per-business tags would break `releases/latest`, which both the update check and
the download page read.

## Work

### Public repo

- [ ] Create `JuniorRaja/orderflow-releases`, public. First commit: a one-line
      `README.md` ("OrderFlow downloads") and `index.html`. Tags need a commit to point at,
      and this is that commit — it is not the code.
- [ ] Turn on GitHub Pages from its default branch, root folder.
- [ ] **Nothing with a business name goes in this repo, ever** — not in files, tags,
      release titles, release bodies or asset names.

### Token

- [ ] Fine-grained personal access token. Repository access: **only
      `orderflow-releases`**. Permission: **Contents — read and write**. Nothing else.
- [ ] Store it in the private repo as the Actions secret `RELEASES_REPO_TOKEN`.
- [ ] Write its expiry date into `docs/development.md`. When it lapses, the release step
      fails in CI; phones are not affected. Renew before that date.
- [ ] The token is used by CI only. It is never in the APK, never in `businesses/*.json`,
      never in the repo.

### Business IDs

- [ ] Add `DOWNLOAD_ID` to every `businesses/<slug>.json` — 12 hex characters, generated
      once with `openssl rand -hex 6`.
- [ ] **An ID never changes.** Every installed phone is matching on it; changing it strands
      them.
- [ ] CI check before building: every business file (except `example.json`) has a
      `DOWNLOAD_ID` of exactly 12 hex characters, and no two files share one. Fail the
      run otherwise.

### CI

- [ ] `.github/workflows/release.yml` — replace the single build with a loop over
      `businesses/*.json`, skipping `example.json` (a test fixture, not a customer).
- [ ] Each build runs
      `flutter build apk --release --flavor <slug> --dart-define-from-file=businesses/<slug>.json`
      and renames the output to `OrderFlow-<DOWNLOAD_ID>-<tag>.apk`.
- [ ] Publish with `softprops/action-gh-release`, setting
      `repository: JuniorRaja/orderflow-releases` and
      `token: ${{ secrets.RELEASES_REPO_TOKEN }}`.
- [ ] **Release title is the tag. Release body is `OrderFlow <version>` and nothing else.**
      Today's body is the git log, and commit messages name businesses, files and
      decisions — that would put all of it on a public page.
- [ ] During the migration only, also publish Milano's APK to `cafe-milano-app` under its
      old name `MilanoOrders-<tag>.apk` — see **Migration** below. Delete this step at
      step 3.

### Update check

- [ ] `lib/services/update_service.dart` — change `_releasesUrl` to
      `https://api.github.com/repos/JuniorRaja/orderflow-releases/releases/latest`.
- [ ] Pick the asset named exactly `OrderFlow-$downloadId-$tagName.apk`, where
      `downloadId` is `String.fromEnvironment('DOWNLOAD_ID')`. Not "the first `.apk`".
- [ ] No matching asset → throw the existing `UpdateCheckException` with a clear message.
      **Never fall back to another asset.**
- [ ] Build-number comparison stays exactly as doc 01 specified.
- [ ] `test/update_service_test.dart` — against a fixture release JSON with three assets:
      picks only its own ID; a release without its ID throws.

### Download page

- [ ] `index.html` in the **public** repo. It fetches that repo's `releases/latest` in the
      browser.
- [ ] `?b=<id>` shows one download button for that ID, with the version and date.
- [ ] **No parameter, or an unknown ID, shows nothing** but one neutral line: "Ask your
      supplier for your download link." It never lists assets.
- [ ] No build step, no framework. Works in a phone browser, because that is where it
      opens.
- [ ] Put the page URL (without any ID) in `docs/development.md`. Each business's full
      link lives in the private repo only, next to their business file.

## Migration — in this order, no skipping

Milano's phone today reads `cafe-milano-app`. Making that repo private first would cut the
phone off from every future update. So:

**Step 1 — `2.1.0` ships to both repos.**

- `orderflow-releases` gets `OrderFlow-<milano id>-v2.1.0-19.apk`.
- `cafe-milano-app` gets **only** `MilanoOrders-v2.1.0-19.apk`, the old name, so the
  installed `2.0.0` — which reads the old repo and takes the first `.apk` — finds it.
- `2.1.0`'s update check points at `orderflow-releases`.

**Step 2 — confirm on Milano's phone.**

- Update to `2.1.0` through the app.
- Tap *Check for updates*: it reports up to date. That proves the new URL and the ID match.
- Ship the next patch (`2.1.1`) and confirm it is offered, and that **Download** opens a
  link on `orderflow-releases`, not `cafe-milano-app`.

**Step 3 — only then make `cafe-milano-app` private**, and delete the dual-publish step
from CI.

Two things to know before step 3:

- **Any phone still on `2.0.0` or older can never update in-app again.** It needs a manual
  install from the download page. Today that is one phone — Milano's — which is why step 2
  is on that phone.
- **Private protects only what comes after.** Everything committed while the repo was
  public — code, history, Milano's name — may already be cloned. That is why no second
  business's config is committed until step 3 is done. `businesses/example.json` is fake
  data and does not count.

## Skipped on purpose

| Skipped | Add when |
|---|---|
| Real release notes in the update dialog | The owner wants them. Then a hand-written notes file in the private repo, reviewed before release — never the git log |
| Authenticated downloads | Hiding the APKs themselves matters. That needs a server — out of scope |
| Per-business tags and feeds | A business needs its own version number |
| Auto-install of the APK | Never. It needs `REQUEST_INSTALL_PACKAGES` |
| A launch-time update check | Never. Checking stays an explicit tap, per doc 01 |

## Notes — what this does and does not hide

- **Hidden:** business names in the public repo, their config files, the code, commit
  history from step 3 onward.
- **Not hidden: how many businesses there are.** The public release lists one APK per
  business.
- **Not hidden: the APK contents.** Anyone can download any asset from the releases page,
  and an installed or unzipped APK shows that business's name and logo. IDs stop casual
  browsing, not a determined look. Closing that needs authenticated downloads.
- The `?b=` filter is courtesy, not security — the GitHub releases page lists every asset.
- All APKs are signed with the same keystore. It stays in CI secrets; `*.jks`, `*.keystore`
  and `*.b64` are gitignored and have never been committed.
- Unauthenticated `api.github.com` allows 60 requests/hour/IP. A manual check and a
  download page are nowhere near that.

## Success criteria

- [ ] A version bump in the private repo produces one release in `orderflow-releases`
      with one `OrderFlow-<id>-<tag>.apk` per business, each signed.
- [ ] **No business name appears anywhere in `orderflow-releases`** — files, tags, release
      titles, bodies, asset names. Checked by reading the public repo page, not the
      workflow.
- [ ] With two or more APKs on a release, Milano's phone is offered only its own ID's APK,
      and **Download** opens `orderflow-releases`. Verified on the phone.
- [ ] A build whose ID is missing from the release reports a check failure. No other APK
      is offered.
- [ ] `?b=<milano id>` shows only Milano's download. No parameter and an unknown ID both
      show nothing.
- [ ] Migration step 2 is confirmed on Milano's phone **before** step 3. After step 3, a
      check on that phone still works.
- [ ] `RELEASES_REPO_TOKEN` does not appear in the built APK, the public repo or any CI log.
- [ ] Installing from the download page over an existing install keeps the data.
