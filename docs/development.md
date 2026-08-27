# Development

[`docs/architecture.md`](architecture.md) has the facts. [`AGENTS.md`](../AGENTS.md) has
the rules.

## Set up

```bash
flutter pub get
```

After any table change, generate the Drift code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

```bash
flutter run
```

`app_database.g.dart` is generated. Do not edit it.

In debug, `dev_seed.dart` restores `dev/seed.json` when it exists. Release builds seed
nothing.

**CAUTION: keep `dev/` in `.gitignore`.** Real business data reached a public repo once.
Doc 02 fixed it.

## Test

```bash
flutter test
```

```bash
flutter analyze
```

```bash
./tool/check_tokens.sh
```

10 test files. They cover the code that carries money: FIFO allocation, the quantity
wheel and its clamp, backup round-trips, DAO behavior, and the migration chain.

The UI needs no unit tests. Money arithmetic does.

**One test fails today:** `v4 -> v5 upgrade` in `migration_test.dart`. Real bug, older
than the current work. [18](features/18-foundation-guardrails.md) fixes it before CI
becomes blocking.

## Release

`master` is production. Never commit to it directly.

One branch per release. One release per branch.

```bash
git switch -c release/1.10.0-design-system
```

1. Do the action items in the feature doc. Commit as often as you like.
2. Make sure that every success criterion passes.
3. Run the readiness gate below. All eight.
4. Set `version:` in `pubspec.yaml` to the target version. Commit.
5. Merge the branch into `master`.

`.github/workflows/release.yml` finds the version change, builds a signed universal APK,
tags, and publishes a GitHub Release. The tag turns `+` into `-`, so `1.10.0+14` becomes
`v1.10.0-14`.

### The readiness gate

Run all eight before you merge. No exceptions.

1. Every success criterion in the feature doc is ticked.
2. `flutter test` — green. Zero failures, zero skips.
3. `flutter analyze` — clean.
4. `./tool/check_tokens.sh` — passes.
5. The APK is installed on the real phone.
6. The smoke pass is done: order entry, kitchen, billing, ledger, record a payment,
   export a statement.
7. A backup from the **previous** version restores into this one.
8. `version:` is bumped.

Step 7 gets skipped and step 7 corrupts real data. Do it.

### Which number to bump

| Change | Bump |
|---|---|
| Anything the user can see or feel | minor |
| Invisible fix, refactor, or tooling | patch |
| The Supabase port | major |

The build number `+N` goes up by one every release. It never resets and never skips. A
release with both a feature and a fix takes the minor bump.
