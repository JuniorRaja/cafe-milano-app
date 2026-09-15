# 17 — White-label

| | |
|---|---|
| **Target version** | `2.0.0+18` |
| **Type** | Major |
| **Schema** | No change. Drift stays frozen at v6 |
| **Builds on** | [10a](10a-design-system.md) — extends the `BrandConfig` it already added |
| **Status** | Ready |

## What this is

The app was built for one bakery. Nothing in it is specific to bread. A sweet
manufacturer supplying 40 dealers does the same five things: hold a product list with
per-customer prices, take a daily order, print a production list, bill it, chase the
money.

This release makes the app rebuildable for another business. One config file, one build
command, a different app on the phone.

**Local-first stays.** SQLite, one user, no login, no server. Each business gets its own
APK and its own database on its own phone. Nothing is shared, so there is nothing to keep
apart.

## What this is not

- Not multi-tenant. There is no shared server, no tenant column, no signup.
- Not a plugin system. One data model for everyone. A customer who needs a different data
  model is a fork, and the answer is no.
- Not module toggles. Every business gets every screen. Add a switch when a customer
  actually asks to hide something.

## What varies, and what does not

| Varies per business | Same for everyone |
|---|---|
| App name, short name, tagline, logo, launcher icon, splash | The data model |
| Package id (`com.<business>.orders`) | Order entry, production list, billing, ledger |
| Brand colours (the `BRAND` token block) | FIFO allocation and the ledger rules |
| Words — "customer" may be shop / dealer / outlet / route; "production" may be kitchen / packing / plant | Every other token: surfaces, text, semantic colours |
| Currency symbol, code and locale | Backup format, release pipeline, update check |

Semantic colours do not vary. Red means something is wrong in every business. A customer
who wants their brand red used for "paid" is asking for a broken app.

## Where config comes from

Two layers, merged at startup.

1. **Compile-time**, from `businesses/<slug>.json` via `--dart-define-from-file`. Name,
   logo, colours, package id, and the default words and currency. Android bakes the
   launcher icon, the app label and the package id into the install, so these cannot be
   runtime values.
2. **In-app overrides**, from a **Business Settings** screen, stored in
   `shared_preferences`. Only the words and the currency. This is what changes during
   onboarding, and rebuilding an APK to rename "customer" to "dealer" is not acceptable.

Overrides win. Anything not overridden falls back to the compile-time value, and anything
missing there falls back to the **OrderFlow defaults** below.

`--dart-define-from-file` only reads flat keys, so the words are flat keys
(`TERM_CUSTOMER`, `TERM_CUSTOMERS`, `TERM_PRODUCTION`), not a nested map.

## Defaults — OrderFlow

The product has its own neutral name. **Milano is no longer the default** — it is one
business file, `businesses/milano.json`, like every other.

| Key | Default | Milano sets |
|---|---|---|
| App name | `OrderFlow` | `Milano Orders` |
| Tagline | `Order, produce, bill, collect` | `Daily Order Manager` |
| Customer word | `customer` / `customers` | `shop` / `shops` |
| Production word | `production` | `kitchen` |
| Currency | `₹`, `INR`, `en_IN` | same |
| Colours, logo | neutral OrderFlow set | today's Milano set |

So Milano's app looks exactly as it does today, and a key a business file leaves out shows
the neutral word, never "shop" or "kitchen".

Three words, not eight. The app has no counter screen (doc 11 is dropped), and "order",
"product", "category" and "bill" already fit every trade.

**Changing a word takes effect on the next app start**, not the next frame. See the
`Terms` note below.

## Work

### Config

- [ ] `lib/theme/brand_config.dart` — add `currencyCode`, `termCustomer`,
      `termCustomers` and `termProduction` to the existing class. Same class, more fields.
      **Do not add a second config class.**
- [ ] `lib/theme/brand_config.dart` — rename `BrandConfig.milano` to
      `BrandConfig.fallback` and give it the OrderFlow values above. Every field reads
      `String.fromEnvironment` with that fallback as its default.
- [ ] `assets/brand/orderflow/` — a plain neutral logo for the fallback. **The owner
      supplies it**; until then the fallback can point at a generic placeholder mark.
- [ ] `lib/config/terms.dart` — new. Three static fields — `Terms.customer`,
      `Terms.customers`, `Terms.production` — and a one-line `.cap` extension for title
      case (`'${Terms.customer.cap} Ledger'`). Set once from the merged config.
      Plurals are given, not derived: `branch` → `branches` breaks any "add an s" rule.

      `ponytail:` statics, not a provider — 120 call sites, most in widgets with no
      `ref`. Cost: a word change needs an app restart. If words ever have to change live,
      move it onto `brandProvider` and plumb `ref`.
- [ ] `lib/providers/bootstrap_provider.dart` — load the saved overrides and set `Terms`
      and the brand override before the gate opens. One read, at startup.
- [ ] Replace every user-visible "shop" and "kitchen" string with a `Terms` field.
      Enumerate them, do not sample:
      `grep -rn "[Ss]hop\|[Kk]itchen" lib/screens lib/widgets lib/services --include=*.dart`
      — about 120 hits, most of them "shop". Watch the concatenated plurals
      (`'shop${n != 1 ? 's' : ''}'`) — they become `n == 1 ? Terms.customer : Terms.customers`.
- [ ] Class names, provider names, table names, JSON backup keys and route paths **stay
      as they are** (`Shop`, `shopProvider`, `/shops`). Renaming them changes nothing the
      user sees and breaks backup restore. User-visible text only.
- [ ] Share-text emojis go neutral for everyone: 🍞 on the production list becomes 📋,
      🏪 on a customer's bill becomes 🧾. Not configurable — two emojis are not worth a
      config key. Milano's share text changes by those two characters.

### Currency

- [ ] `lib/utils/money.dart` — drive the formatter with `currencyCode`, `currencySymbol`
      and `locale` together. It is already the only place money becomes text, so this is
      one file.
- [ ] Keep Indian grouping working. `₹1,24,680` is not `$124,680` with a different sign —
      the locale does the grouping, and that is the thing to test.

### Business Settings screen

- [ ] `lib/screens/settings/business_settings_screen.dart` — new. Three text fields for
      the words (customer, customers, production), three for the currency (symbol, code,
      locale), Save, and Reset to defaults. Built from the existing kit — no new UI primitives.
- [ ] Save writes one JSON string to `shared_preferences` and tells the user the change
      applies after restarting the app. Say it plainly in the UI; do not pretend it is
      live.
- [ ] Add the tile to the Settings screen, in the style [10b](10b-navigation.md) sets.

### Build

- [ ] `businesses/milano.json` — `APP_NAME`, `SHORT_NAME`, `TAGLINE`, `LOGO_ASSET`,
      `BRAND_PRIMARY`, `BRAND_DEEP`, `BRAND_DEEPEST`, `BRAND_MARK`, `CURRENCY_SYMBOL`,
      `CURRENCY_CODE`, `LOCALE`, `TERM_*`, `BUSINESS_SLUG`. Milano's current values,
      exactly. (`DOWNLOAD_ID` is added in [13](13-distribution-docs.md).)
- [ ] `businesses/example.json` — a second file with different values, kept in the repo as
      the proof the seam works. It is the test fixture, not a customer.
- [ ] `android/app/build.gradle.kts` — product flavors, one per business, each with its own
      `applicationId` and app label. **Milano keeps `com.cafemilano.cafe_milano`.**
      Renaming it would orphan the owner's installed app and its database.
- [ ] `assets/businesses/<slug>/` — logo, launcher icon, splash image.
- [ ] Per-flavor `flutter_launcher_icons-<slug>.yaml` and
      `flutter_native_splash-<slug>.yaml`. Both packages are already dependencies and both
      support flavors.
- [ ] Build command, written into `docs/development.md`:
      `flutter build apk --flavor <slug> --dart-define-from-file=businesses/<slug>.json`

CI, per-business releases and the update check are [doc 13](13-distribution-docs.md), the
next release. This one is finished when the command above produces a different app.

## Skipped on purpose

| Skipped | Add when |
|---|---|
| Module on/off flags | A customer asks to hide a screen |
| A config table in the database | Never — the settings fit in `shared_preferences`, and the schema stays frozen |
| `.arb` / `intl` localisation | A customer needs a language, not eight nouns. Then it is a different doc |
| Live word changes with no restart | Somebody complains about the restart |
| Per-business custom fields or screens | Never. That is a fork |

## Tests

- [ ] `test/terms_test.dart` — render the main screens with the terms set to `dealer` /
      `dealers` / `packing`; assert "shop", "customer", "kitchen" and "production" appear
      nowhere.
- [ ] `test/money_test.dart` — the same figure under `en_IN` and `en_US`. The lakh
      separator is what is being asserted, not the symbol.
- [ ] A defaults test: no config renders "OrderFlow", "customer" and "production" —
      never "Milano", "shop" or "kitchen".
- [ ] No test asserts a colour value. A test pinning `#FFC000` makes the seam useless.

## Success criteria

- [ ] `flutter build apk --flavor example --dart-define-from-file=businesses/example.json`
      produces an app with a different name, icon, colour, words and currency, with **zero
      business-specific code in `lib/`**. Any `if (slug == 'example')` fails this outright.
- [ ] With `businesses/milano.json`, the app reads exactly as `1.13.0` does — "shop",
      "kitchen", Milano's name and colours — apart from the two share emojis.
- [ ] `grep -rn "Milano" lib/` returns nothing. Milano exists only in
      `businesses/milano.json` and `assets/businesses/milano/`.
- [ ] Renaming "customer" to "dealer" in Business Settings and restarting changes every screen.
      Verified by looking at the app, not by grep — grep cannot see a concatenated string.
- [ ] `grep -rn "₹" lib/` returns nothing outside `money.dart`.
- [ ] Both apps install side by side on one phone and keep separate databases.
- [ ] **The Milano install upgrades in place, keeps its package id, and loses no data.**
      This cannot be waived.
- [ ] A backup exported from `1.12.0` restores into this build.

## Onboarding a new business

**Not before [13](13-distribution-docs.md) is shipped and the code repo is private.** Step 1
commits a real business's config, and anything committed while the repo is public may
already be cloned. `2.0.0` ships with only `milano.json` and the fake `example.json`.

Target: under one working day.

1. Write `businesses/<slug>.json`. Drop logo, icon and splash into
   `assets/businesses/<slug>/`.
2. Add the Android flavor.
3. Build, install, open Business Settings, set the words and currency with the customer
   sitting there.
4. Enter their products, categories and customers — or import them through the existing
   backup-restore path.
5. Hand over the APK. Walk them through one real day of orders.

Step 4 is the honest unknown. If a customer turns up with 300 products in a spreadsheet,
write the CSV-to-backup-JSON converter then — not before, and not as guesswork.
