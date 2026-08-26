# 17 — White-label

| | |
|---|---|
| **Target version** | `3.0.0+23` |
| **Type** | Major |
| **Schema** | Postgres only — one config table per tenant project |
| **Requires** | [14 — Supabase, auth & roles](14-supabase-auth.md) |
| **Builds on** | [10a — Design system & UI foundation](10a-design-system.md) — extends its `BrandConfig` seam |
| **Status** | **Outline** — expand into its own numbered sequence before starting |

## Why

This app was built for one bakery. Nothing in it is specific to bread.

A central kitchen in Chennai supplying 18 shops, a sweet manufacturer supplying 40
dealers, a dairy distributor running 12 routes, a pickle maker shipping to 25
retailers — they all do the same five things this app already does: hold a product
catalogue with per-customer prices, take a daily order per customer, produce a
consolidated production list, bill it, and chase the money. The owner's stated
ambition is to sell that, and the honest position is that the product is most of the
way there and the remainder is the word "Milano" and one module.

[Doc 10a](10a-design-system.md) has already taken the first half. Brand colour, logo
and app name resolve through `BrandConfig` in `lib/theme/brand_config.dart`; there
are **zero** hardcoded "Milano" strings left in `lib/`; currency runs through a single
formatter; and swapping `BrandConfig.milano.primary` restyles the entire app, which
10a made a success criterion precisely so this doc would not have to prove it. **This
doc extends that seam. It does not invent one, and it does not rebuild it.**

What 10a deliberately left:

- **`brandProvider` returns a compile-time constant.** `Provider<BrandConfig>((ref) =>
  BrandConfig.milano)`. There is a seam but nothing feeds it.
- **Business terminology is still hardcoded**, by explicit decision in 10a —
  roughly **77 user-visible strings across 21 files** contain the word "shop", and
  "kitchen" is written into the nav, the share sheet and the screen title.
- **`BrandConfig` carries a currency *symbol* and a locale but no currency code.**
  That is enough for `₹` and Indian digit grouping and not enough for
  `NumberFormat.currency`.
- **The package id is `com.cafemilano.cafe_milano`**, in `android/app/build.gradle.kts`,
  along with the app label, the launcher icon and the splash.
- **Counter stock ([doc 11](11-counter-stock.md)) exists because Cafe Milano owns one
  of its own outlets.** Almost no other customer will, and it must be switchable off.

### What this is not

**This is not a multi-tenant SaaS rewrite.** Take that as decided.

There is no shared application serving many customers, no tenant column threaded
through every query, no self-serve signup, no billing system, no in-app tenant
creation. This is a **product built per customer** — one Supabase project, one APK,
one onboarding session — and the entire design follows from accepting that the
customer count is measured in tens, not thousands.

If the customer count ever passes roughly **30**, the arithmetic in **The backend
decision** below changes and the decision gets reopened. Not before.

### What varies, and what does not

| Varies per tenant | Fixed for every tenant |
|---|---|
| App name, logo, splash, launcher icon, package id | The data model |
| Brand colour tokens (the 10a `BRAND` block) | Order entry, kitchen list, billing flow |
| Terminology — "shop" may be outlet / dealer / route / client; "kitchen" may be production / plant | FIFO allocation and the ledger rules ([05](05-ledger-foundation.md)–[07](07-ledger-statements.md)) |
| Enabled modules — counter stock, ledger, suggestions, weekly report | The three-tier role matrix ([14](14-supabase-auth.md)) |
| Currency symbol, code and locale | Backup format, release pipeline, update mechanism |
| Supabase project URL and anon key | Everything in 10a's `SURFACE`, `TEXT` and `SEMANTIC` token blocks |

The semantic palette is deliberately in the right-hand column. Red means something is
wrong in every tenant; a customer who wants their brand red used for "paid" is asking
for a broken app, and the answer is no.

A customer who needs a different **data model** is not a tenant. They are a fork, and
the answer is also no.

## Data model

One config table, in **each** tenant's own Supabase project. It holds exactly one row.

```
tenant_config                 -- single row; id = 1 enforced by CHECK
  id            INT PK CHECK (id = 1)
  slug          TEXT          -- 'milano', 'acme-sweets'
  terms         JSONB         -- {"shop":"dealer","shops":"dealers","kitchen":"plant",...}
  modules       JSONB         -- {"counter_stock":false,"ledger":true,
                               --  "suggestions":true,"weekly_report":false}
  currency_code TEXT          -- 'INR'
  currency_sym  TEXT          -- '₹'
  locale        TEXT          -- 'en_IN'
  updated_at    TIMESTAMPTZ
```

Three rules that are easy to get backwards:

- **Brand tokens are compile-time and are deliberately not in this table.** Android
  bakes the launcher icon, the app label and the package id into the install; they
  cannot be runtime values. Splitting brand across two mechanisms so that *some* of
  it is live would create a "which one wins" question with no good answer. Colours
  change approximately never; terminology and module flags change during onboarding,
  which is exactly when re-cutting and redistributing an APK to twenty phones is most
  painful. That is where the line is drawn, and it is drawn there on purpose.
- **The table is read once after sign-in and cached for the session.** Everything
  rendered before sign-in — splash, login screen, app name — comes from the
  `--dart-define` values compiled in, which is where `BrandConfig` already gets them.
  A change to this table takes effect on the next app start, not the next frame.
- **Terminology is a lookup, not a localisation layer.** Around eight keys, English
  only, singular and plural given explicitly. The alternative — a proper `intl` /
  `.arb` pipeline — lost: this needs eight nouns swapped, not four hundred strings
  translated, and the moment it becomes an `.arb` pipeline every new string in the app
  needs a translation round-trip forever. If a customer ever needs Tamil, that is a
  different doc and a real decision.

Missing keys fall back to the Milano defaults. A tenant that sets nothing gets the app
exactly as it ships today.

## The backend decision

**One Supabase project per tenant.** Not a shared project with a `tenant_id` column.

Defended on the three grounds that matter:

- **Blast radius.** In a shared project, one wrong RLS policy exposes every customer's
  shop list, prices and revenue to every other customer — and customers of a product
  like this are frequently in the same trade in the same city. Per-project, the worst
  case of the same mistake is one customer seeing their own data wrongly. When the
  entire content of the database is a competitor-sensitive customer list and a price
  sheet, that asymmetry decides it on its own.
- **RLS complexity.** [Doc 14](14-supabase-auth.md)'s policy matrix is already three
  roles across six resource groups. A tenant column multiplies every one of those
  policies by a tenant predicate, and every policy becomes a place to forget
  `AND tenant_id = …`. One omission is a cross-customer leak. The same omission in a
  per-project model is nothing at all.
- **Per-customer cost.** This is where the shared model genuinely wins, and it should
  be stated in dollars rather than waved at: Supabase Pro is **$25 per project per
  month**. Ten tenants is **$250/month** against a shared project's $25. That is the
  real price of the decision and it is accepted, because a product sold to a central
  kitchen recovers $25 immediately, and because tenants one to ten arrive over years,
  not in a launch week.

Two more consequences, one in each direction. In favour: backup, export and
offboarding are trivial — a customer who leaves takes a project, not a
`DELETE FROM … WHERE tenant_id`, and `lib/services/backup_service.dart` already
round-trips a whole database. Against: there is **no cross-tenant analytics, ever**,
and every schema change must be applied to N projects. The second is real and its
mitigation is not optional — see `tool/apply_migration.dart` below. **From tenant #2
onward, no migration is ever applied by hand.**

## Outline of work

### Config seam — extends [doc 10a](10a-design-system.md)'s BrandConfig

- [ ] `lib/theme/brand_config.dart` — add `currencyCode`, `terms` and `modules` to the
      existing class. Same object, more fields; **do not add a second config class**,
      which is the one way to make 10a's seam worse than no seam.
- [ ] `lib/theme/brand_config.dart` — `BrandConfig.milano` stops being the value
      `brandProvider` returns and becomes the **defaults** the tenant config merges
      over. Milano is a tenant like any other from this doc onward, not a special case
      in the code.
- [ ] `lib/providers/tenant_provider.dart` — new. Reads the `--dart-define` values at
      startup, loads `tenant_config` once after sign-in, merges, and overrides
      `brandProvider`. One load, cached for the session. Not `autoDispose` — it is
      genuinely app-lifetime, in the same list as `databaseProvider` and
      `selectedDateProvider` in 10a's provider rule.
- [ ] `lib/config/terms.dart` — new. `Terms.shop`, `Terms.shops`, `Terms.kitchen`,
      `Terms.counter`, and the capitalised variants. About eight keys. **Every**
      user-visible occurrence routes through it — enumerate all ~77 with
      `grep -rn "[Ss]hop" lib/screens lib/widgets --include=*.dart`; do not sample.
      This is the sweep 10a explicitly deferred here.
- [ ] Currency: extend 10a's formatter to `NumberFormat.currency` driven by
      `currencyCode`, `currencySymbol` and `locale` together. 10a already removed the
      ~30 literal `₹` call sites, so this is a change in **one file**, which is the
      whole return on 10a having done it first. The trap to keep stated: Indian digit
      grouping is not `en_US` grouping — `₹1,24,680` versus `$124,680` — so this was
      never a symbol swap.
- [ ] Module gating in `lib/app.dart`: a disabled module's **routes are not
      registered**, not merely hidden. A hidden route is still reachable by deep link,
      and a deep link into a module whose tables the tenant never uses is a crash
      report, not a feature.
- [ ] `lib/widgets/shell/drawer_destinations.dart` — filter by module flag.
      [Doc 10b](10b-navigation.md) already made the destination list **data** rather
      than markup, so this is a `where` clause and not a rewrite. That was worth the
      wait.
- [ ] `lib/widgets/floating_nav_bar.dart` — the Counter slot disappears for tenants
      with `counter_stock: false`. 10b already made the bar role-scoped; module scoping
      is the same mechanism with a second predicate.

### Backend

- [ ] `supabase/migrations/…_tenant_config.sql` — the table above. RLS `SELECT` for
      all three roles (terminology is not secret), `UPDATE` for owner only.
- [ ] `tool/apply_migration.dart` — new. Applies one migration file to every project
      listed in `tenants/`, reports per-project success or failure, and **refuses to
      continue past a failure** rather than leaving the estate half-migrated. Written
      **before** tenant #2 exists, not after.
- [ ] `tool/seed_tenant.dart` — new. Converts a customer's CSV of products, prices and
      customers into the backup JSON that `lib/services/backup_service.dart` already
      imports. That path exists and is tested; do not write a second one.
- [ ] Provisioning as a script where possible and a written checklist where not. A
      provisioning step that lives only in someone's memory is the step that gets
      missed on tenant #4.

### Build and distribution

- [ ] `tenants/<slug>.json` — one file per tenant: `TENANT_SLUG`, `APP_NAME`,
      `SHORT_NAME`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `BRAND_PRIMARY`,
      `BRAND_DEEP`, `BRAND_DEEPEST`, `BRAND_MARK`, `CURRENCY_SYMBOL`,
      `CURRENCY_CODE`, `LOCALE`. Consumed with `--dart-define-from-file`.
- [ ] Android product flavors in `android/app/build.gradle.kts` — per-flavor
      `applicationId` (`com.<tenant>.orders`) and app label. **Milano keeps
      `com.cafemilano.cafe_milano` unchanged**; renaming an existing package would
      orphan the owner's installed app and its database, and no amount of tidiness is
      worth that.
- [ ] Per-flavor assets under `assets/tenants/<slug>/` — logo, launcher icon, splash.
      `flutter_launcher_icons` and `flutter_native_splash` are already dependencies and
      both take per-flavor configuration.
- [ ] Build command:
      `flutter build apk --flavor <slug> --dart-define-from-file=tenants/<slug>.json`.
- [ ] `.github/workflows/release.yml` — build the tenant matrix on a version bump.
      Tag becomes `v{version}-{slug}` (e.g. `v3.0.0-23-acme`); the asset becomes
      `{AppName}-v{version}.apk`.
- [ ] **`lib/services/update_service.dart` must change.** It currently hits
      `releases/latest` on a single repo ([doc 01](01-in-app-update.md)) — with
      per-tenant releases, "latest" is whichever tenant was built most recently, and
      every tenant would be offered somebody else's APK. It moves to listing
      `releases` and selecting the newest tag carrying its own slug. Build-number
      comparison stays exactly as doc 01 specified. This is the part of
      white-labelling that is always forgotten, and it is a live-update bug on every
      device the day tenant #2 ships.
- [ ] [Doc 13](13-distribution-docs.md)'s download page takes `?tenant=<slug>` and
      filters the same way.
- [ ] **The distribution consequence, stated plainly:** the repo is public and it
      stays public — that is what makes the unauthenticated release lookup in doc 01
      work at all, and a private release repo would force a GitHub token into the APK,
      which doc 01 rejected for reasons that still hold. So every tenant's APK, app
      name and Supabase URL are publicly visible. The anon key being public is fine
      (RLS is the boundary, per doc 14); **the customer list being public is a business
      decision, not a technical one**, and the owner has to make it knowingly before
      tenant #2 ships.

### Onboarding, end to end

The whole doc is judged on how long this takes. Target: **under one working day** for
a customer arriving with a clean product and customer list.

1. Create the tenant's Supabase project. Apply the schema with
   `tool/apply_migration.dart`. Insert the `tenant_config` row.
2. Create the owner user by hand in the Supabase dashboard. **Public signup stays
   disabled**, per doc 14 — this doc does not re-open it.
3. Write `tenants/<slug>.json`; drop brand assets into `assets/tenants/<slug>/`.
4. Convert the customer's CSV with `tool/seed_tenant.dart` and import it through the
   existing backup-restore path.
5. Bump the version, push, let CI build and publish the tenant-tagged release.
6. Hand over the download link (doc 13's page with `?tenant=<slug>`) and the owner
   credentials. Walk them through one real day of orders.

### Tests

- [ ] A terminology test rendering the key screens under a tenant whose `terms` map
      replaces every key, asserting the word "shop" appears nowhere.
- [ ] A currency test covering `en_IN` against `en_US` on the same figure — the lakh
      separator is the specific thing being asserted, not the symbol.
- [ ] A module-gating test: with `counter_stock: false`, the route is not registered
      and navigating to `/counter` does not resolve.
- [ ] A defaults test: an empty `tenant_config` renders identically to Milano.
- [ ] **Still no test asserts a colour value**, per 10a. A test pinning `#FFC000` makes
      the seam this doc depends on useless.

## Success criteria

- [ ] A second tenant — different name, logo, colour, package id, terminology and
      currency — runs from the same `master` with **zero tenant-specific code outside
      `tenants/<slug>.json` and `assets/tenants/<slug>/`**. Any `if (tenant ==
      'acme')` anywhere in `lib/` fails this criterion outright.
- [ ] The word "shop" appears in **0** user-visible strings for a tenant whose `terms`
      map renames it. Verified by rendering, not by grep — grep cannot see a string
      that was concatenated.
- [ ] `grep -rn "₹" lib/` returns **0** results outside the currency formatter, and
      that formatter is the only place `NumberFormat` is constructed.
- [ ] `BrandConfig.milano` is referenced in exactly **one** place — the merge in
      `tenant_provider.dart`.
- [ ] With `counter_stock` disabled, `/counter` does not resolve, the drawer entry does
      not exist, and the nav bar has three slots. Verified by attempting the deep link,
      not by looking at the drawer.
- [ ] Both tenants install **side by side on one device** and keep separate databases.
      This is the real proof the package-id split worked.
- [ ] Each tenant's in-app update check offers **only that tenant's** APK, with two
      tenants published at different versions.
- [ ] Onboarding a new tenant from a clean CSV to a working signed APK takes under
      **one working day**, timed on the first real customer.
- [ ] A schema migration applies to all N projects from one `tool/apply_migration.dart`
      invocation, and a deliberately failing project halts the run.
- [ ] **The Milano install upgrades in place, keeps its package id, and loses no
      data.** This criterion cannot be waived for any reason.

## Notes

### Why this is a major

The [roadmap](../roadmap.md)'s bump table calls for a major on "Supabase / auth /
multi-user". This is literally none of those, and it is a major anyway, on the rule
the table is really expressing: **a change users cannot roll through.** A build whose
`applicationId` changes is a different installed app — it cannot upgrade over an
existing install — and the single `releases/latest` feed that
[doc 01](01-in-app-update.md)'s updater and [doc 13](13-distribution-docs.md)'s
download page both depend on stops existing. Neither of those is a minor. The build
number continues from [doc 16](16-weekly-ai-report.md)'s `+22`, as it always does.

### This splits, and it is the largest of the three

It is the biggest doc in this round and must not be attempted as one release. Split it
into its own sequence, exactly as [doc 14](14-supabase-auth.md) does and as
[doc 10](10-ui-overhaul.md) already did once in this roadmap:

- **`17a` — the config seam.** `BrandConfig` extension, `Terms`, the currency change,
  module gating, `tenant_config`, `tenant_provider`. Ships to Milano as an ordinary
  release and changes nothing visible. Takes `3.0.0+23`.
- **`17b` — build and distribution.** Flavors, `--dart-define-from-file`, per-tenant
  assets, tenant-tagged releases, the `update_service.dart` change, the download-page
  filter.
- **`17c` — the first real tenant.** `apply_migration.dart`, `seed_tenant.dart`, the
  onboarding run, and the honest test of all of it.

Stated plainly: **17a and 17b are worth doing even if a second customer never
appears.** They finish the job 10a started, put currency in one place, and make the
release pipeline explicit — all of which the app is better for on its own. **17c is
worth nothing until a signed customer exists** and must not be built speculatively;
every part of it is guesswork until a real customer's CSV is on the table.

### Permanently out of scope

Not "later" — **not in this product**, unless the business model changes:

- **Self-serve signup.** Doc 14 disabled public signup deliberately. This doc keeps it
  disabled. Tenants are onboarded by a person.
- **A billing or subscription system.** Customers are invoiced outside the app.
- **In-app tenant creation** or a tenant admin console. Provisioning is a script and a
  checklist run by the operator.
- **Per-tenant custom fields, custom screens or a plugin system.** The moment one
  customer's schema differs, this stops being one product.
- **Cross-tenant analytics.** Ruled out by the per-project decision and accepted as
  its price.
- **Dark mode.** Still out, for the reason 10a gives — the app is used at 5 a.m. in a
  kitchen. A tenant asking for it does not change that, and a half-built dark mode is
  worse than none.
