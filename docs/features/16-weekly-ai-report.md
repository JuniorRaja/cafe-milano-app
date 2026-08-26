# 16 — Weekly AI business report

| | |
|---|---|
| **Target version** | `2.2.0+22` |
| **Type** | Feature |
| **Schema** | Postgres only — one new table, written server-side |
| **Requires** | [14 — Supabase, auth & roles](14-supabase-auth.md) |
| **Builds on** | [10a — Design system & UI foundation](10a-design-system.md) for the component kit |
| **Draws on** | [05](05-ledger-foundation.md) · [06](06-ledger-manual-allocation.md) · [07](07-ledger-statements.md) for collections, [11](11-counter-stock.md) for waste, [12](12-dashboard-tabs.md) for the aggregates |
| **Status** | **Outline** — expand action items before starting |

## Why

The dashboard answers questions the owner already knows to ask. Nothing in this app
tells him something he was not looking for.

By the time [doc 12](12-dashboard-tabs.md) has shipped, the app holds a week of ~18
shops, six or seven categories, roughly 28 products, every payment and every
outstanding bill, and counter waste for shop #1. All of it is on screen and none of
it is read on a Monday morning, because reading four tabs of charts is work and
nobody does it while the kitchen is running.

A weekly report is the format that actually gets read: one page, once a week, in
plain sentences, saying what moved and what to do about it. "Bread revenue fell 14%
this week, all of it at the three Adyar shops" is a thing the owner would act on and
will never notice on a heatmap.

What a week's report contains:

- **Revenue vs the prior week** — total, and per delivery day.
- **Category and product movement** — which of puffs / buns / rolls / cakes / bread /
  biscuits moved, and the products behind it.
- **Shop concentration** — the top shops by share, and any shop that moved sharply.
- **Collection health** — billed, collected, outstanding, shops overdue beyond 14
  days, and the oldest open bill, from [docs 05–07](05-ledger-foundation.md).
- **Waste and sell-through** at the Cafe Milano counter, from
  [doc 11](11-counter-stock.md).
- **Two or three concrete recommended actions**, each naming a shop or a product and
  a number.

**Explicitly out of scope: this feature computes nothing new.** Every figure in the
report already exists because the dashboard computes it. If a number is wanted that
the dashboard does not have, it is a dashboard change first and this doc reads it
second. This is a delivery mechanism, not an analytics layer.

Also out of scope: daily reports, per-shop reports, and anything the owner can ask
follow-up questions to. This is one page, once a week, one direction.

## Where the model call happens, and why it is not on the phone

**The Claude API call happens server-side, in a Supabase Edge Function on a
schedule. The API key never goes anywhere near the APK.**

This is not a preference. An APK is a zip file; `strings` over the binary finds an
embedded key in under a minute, and this project publishes its APKs publicly from
GitHub Releases ([doc 01](01-in-app-update.md), [doc 13](13-distribution-docs.md)).
[Doc 14](14-supabase-auth.md) already makes the distinction that matters: the
Supabase **anon** key ships in the app because RLS is the security boundary behind
it, and the **`service_role`** key never does because nothing stands behind it. An
Anthropic API key is the second kind. There is no RLS for a billing account — the
only boundary is a spending limit, and the only person it limits is the owner.

Consequences that follow and are accepted:

- The report is generated whether or not the phone is on. That is an improvement,
  not a compromise — the owner should not have to open an app to receive a report.
- The Edge Function runs with the `service_role` key, so it reads across every table
  without RLS. It is the only component in this project that does, and its query set
  must therefore be **fixed SQL in the repository**, never a query assembled from
  anything the model produced.
- `ANTHROPIC_API_KEY` lives in Supabase secrets. It is not in the repo, not in CI
  logs, not in the app.

## Data model

Postgres only. There is no Drift schema hop here — by this point
[doc 14](14-supabase-auth.md) has ported the app off Drift, and this table is created
by the same Edge Function migration that ships the feature.

```
weekly_reports                -- append-only; written by the Edge Function alone
  id             BIGSERIAL PK
  week_start     DATE UNIQUE  -- Monday, IST
  week_end       DATE         -- Sunday, IST
  status         TEXT         -- ok | skipped | failed
  payload        JSONB        -- the exact aggregate object sent to the model
  sections       JSONB        -- the model's structured output, placeholders unresolved
  narrative      TEXT         -- rendered text after substitution
  model          TEXT         -- e.g. claude-opus-5
  input_tokens   INT
  output_tokens  INT
  cost_usd       NUMERIC
  error          TEXT NULL
  generated_at   TIMESTAMPTZ

business_info
  + weekly_report_enabled  BOOLEAN NOT NULL DEFAULT true
  + weekly_report_email    TEXT NULL
```

Three rules that are easy to get backwards:

- **`payload` is stored, not just the narrative.** Without the exact input, a wrong
  figure in a report cannot be traced to whether the SQL or the model produced it,
  and that is the only question worth asking when a wrong figure appears. It is a few
  kilobytes a week.
- **The app can read this table and cannot write it.** RLS: `SELECT` for owner and
  manager, nothing for staff (consistent with doc 14's matrix — staff see no revenue
  and no ledger). No role has `INSERT` or `UPDATE`; only the `service_role` key
  writes.
- **`UNIQUE (week_start)` makes re-runs idempotent.** A retry upserts the same week.
  Without it, a manual retry after a failure produces two reports for one week and
  the archive stops making sense.

`status = 'skipped'`, `status = 'failed'` and a missing row are three different
things and must render as three different things. See **Failure behaviour** below.

## What the model receives

**A compact pre-aggregated JSON summary. Never rows.**

Hard bound: **≤ 12 KB of JSON, ≤ ~4,000 input tokens.** The payload builder asserts
the size and fails the run rather than sending something larger.

Contents, all of it already computed by the dashboard's aggregates:

| Block | Shape | Cap |
|---|---|---|
| Period | week start/end, days with orders, prior-week start/end | — |
| Totals | revenue, order count, shops served — this week and prior | — |
| By weekday | revenue for each of the 7 days, this week and prior | 14 numbers |
| Categories | name, revenue, qty, Δ% vs prior | all (~7) |
| Products | name, category, revenue, qty, Δ% | top **10** by revenue |
| Shops | name, area, revenue, share %, Δ% | top **8** by revenue |
| Collections | billed, collected, outstanding, shops overdue > 14d, oldest open bill age | — |
| Counter | produced, sold, waste, waste %, sell-through % | plus **5** worst products |

**Truncation is by rank, never by sampling, and never silent.** When a list is cut,
the tail collapses into one `{"name": "other", ...}` row carrying its total, so every
list still sums to the block total the model is also given. A model handed a top-10
that does not sum to the stated total will explain the gap, incorrectly.

### Why not raw rows

One week is roughly 18 shops × 6 days × 12 lines ≈ **1,300 order lines**; with the
prior week for comparison, ~2,600; a month of context, ~5,500. Three reasons that
loses, in order of weight:

1. **It is worse.** A model asked to total 2,600 line items produces a number that is
   approximately right. `SUM()` produces the number. The same SQL has been computing
   these aggregates on the dashboard for months and is already trusted; replacing it
   with prose arithmetic is a downgrade dressed as a capability.
2. **Cost.** ~2,600 lines is roughly 120,000 input tokens against 4,000 — thirty times
   the input cost, every week, for a worse answer.
3. **Latency.** A 120K-token prompt is tens of seconds of a scheduled function's
   budget for no gain.

The model's job is to notice, connect and phrase. Arithmetic is not on the list.

### Every number comes from the payload

The model **writes prose around figures it is handed**. It never produces a figure.
Enforced in three layers, not one:

1. **Placeholders, not literals.** The prompt supplies a fixed token list —
   `{{revenue_this_week}}`, `{{revenue_delta_pct}}`, `{{top_product_name}}`,
   `{{outstanding_total}}`, and so on — one for every figure the report is allowed to
   mention, including pre-computed deltas and percentages so the model never has a
   reason to calculate one. The model writes
   `Revenue rose to {{revenue_this_week}}, up {{revenue_delta_pct}} on last week.`
2. **Substitution and rejection.** The Edge Function substitutes from the payload. A
   placeholder that is not in the supplied list, or that resolves to nothing, fails
   the run — it does not render as an empty string and it does not get dropped.
3. **A digit scan on the rendered output.** After substitution, any bare digit
   sequence in the narrative that did not come from a substitution fails validation.
   The allow-list is small and explicit: the week's date labels and nothing else.

A hallucinated figure is therefore caught at step 2 if the model invented a
placeholder, and at step 3 if it typed a number directly. Both paths end in
`status = 'failed'` with the raw output stored, which is exactly the artefact needed
to fix the prompt.

The alternative — let the model write literals, then verify each number against the
payload by fuzzy match — lost. It needs the same substitution table to verify
against, and it **fails open** on a near miss: ₹24,860 against a true ₹24,680 is one
transposition, reads entirely plausible, and passes any tolerance loose enough to
survive rounding.

Prose the model writes freely: the framing, the connections between blocks, and the
recommended actions. Those are judgements, not figures, and each recommendation still
has to name a shop or product and carry a placeholder.

### Model and cost

**`claude-opus-5`.** One line of reasoning: the job runs 52 times a year on a 4 KB
payload, so cost cannot decide it, and the half of the output that has to be worth
reading — the recommended actions — is business judgement rather than
summarisation.

Per report, at $5/MTok input and $25/MTok output: ~5,000 input tokens (payload plus
system prompt) ≈ **$0.025**, ~1,800 output tokens ≈ **$0.045**. **≈ $0.07, about ₹6 a
report — roughly ₹310 a year.**

`claude-haiku-4-5` at $1/$5 would cost ~₹1.30 a report. It lost: this is the only
part of the product whose entire value is whether the prose is worth reading, and the
saving is under ₹5 a week.

The **Batch API** would halve even that. It lost too — the Edge Function would have to
return later to collect the result, which means a second scheduled invocation and a
pending state in the table, for a saving of ₹3 a week.

Request shape, so it is not rediscovered during implementation: adaptive thinking (on
by default on `claude-opus-5`), `output_config.effort: "medium"` — a 4 KB payload
does not need more — structured outputs via `output_config.format` so the sections
come back as fixed keys rather than prose the function has to parse, and
`max_tokens: 4000` non-streaming.

Deliberately **not** using the server-side `fallbacks` parameter, which the Claude API
docs otherwise recommend by default on `claude-opus-5`. A refusal on a payload of
aggregated bakery figures means something has gone wrong with the request, and quietly
re-running it on a weaker model produces a report the owner cannot tell apart from a
good one. Fail visibly and retry — the table below.

## Failure behaviour

| Situation | Behaviour |
|---|---|
| Model call errors, or `stop_reason` is `refusal` | Retry **once** after 60 s. On the second failure write `status = 'failed'` with the error, send **no** email. |
| Validation rejects the output (steps 2–3 above) | Same path. The raw `sections` are stored anyway — that is the debugging artefact. |
| Week has **no orders at all** | **No model call.** Write `status = 'skipped'`. Paying to have a model write "nothing happened" is a bug. |
| Week has fewer than 3 days with orders | Generate normally, but the payload carries `days_with_data` and the prompt is told to open by saying so. |
| Report disabled in settings | Function exits before assembling the payload. Nothing written. |

In the app, a failed week reads *"Last week's report could not be generated"* with a
**Retry** button that re-invokes the function for that week. **An absent report and a
failed report must never look the same** — silence is how the owner stops trusting a
scheduled thing.

## Outline of work

### Server

- [ ] `supabase/functions/weekly-report/index.ts` — new. Deno + `@anthropic-ai/sdk`.
      Reads settings → assembles payload → calls the model → validates → substitutes
      → writes the row → sends the email. Each stage a separate function, so each is
      testable alone.
- [ ] `supabase/functions/weekly-report/queries.sql` — the fixed aggregate set,
      mirroring `lib/database/daos/dashboard_dao.dart` and doc 07's outstanding
      query. **Fixed SQL in the repository**; nothing is assembled from model output.
- [ ] `supabase/functions/weekly-report/payload.ts` — builder plus the 12 KB / 4,000
      token assertion and the rank-truncation with the `other` row.
- [ ] `supabase/functions/weekly-report/validate.ts` — placeholder substitution,
      unknown-placeholder rejection, and the digit scan.
- [ ] `supabase/migrations/…_weekly_reports.sql` — the table above, the two
      `business_info` columns, and the RLS policies (owner/manager `SELECT` only).
- [ ] Schedule: `pg_cron`, **Monday 04:00 IST = Sunday 22:30 UTC**, covering the
      Monday–Sunday week just ended. Write it in UTC in the cron entry and put the
      IST time in a comment beside it — a schedule that silently drifts by 5½ hours
      is the classic version of this bug.
- [ ] `ANTHROPIC_API_KEY` in Supabase secrets. Add it to
      [doc 13](13-distribution-docs.md)'s agent docs as a secret that must never
      reach the repo, CI, or the app — the same sentence doc 14 writes about
      `service_role`.
- [ ] Email via a transactional provider (Resend), called from the same function,
      `weekly_report_email` as the recipient. Supabase's auth SMTP is **not** used:
      it exists for auth mail, and putting product mail through it entangles login
      deliverability with something nobody will monitor.

### App

- [ ] `lib/screens/reports/weekly_report_list_screen.dart` — new. The archive: one
      row per week, newest first, showing the week range, headline revenue, and a
      status marker for skipped and failed weeks. Composed from
      [doc 10a](10a-design-system.md)'s kit — `AppScaffold`, `ListRow`,
      `StatusBadge`, `EmptyState`, `AppSkeleton`. **No new UI primitives.**
- [ ] `lib/screens/reports/weekly_report_screen.dart` — new. One report, rendered as
      readable prose with `SectionHeader` per section from `sections`, figures in the
      `displayL` / `titleM` type steps, and `DeltaPill` for the week-on-week moves.
      Share as text. Currency goes through doc 10a's formatter — no literal `₹`.
- [ ] `lib/providers/weekly_report_provider.dart` — new. `weeklyReportsProvider`
      (list), `weeklyReportProvider.family` (one week), both **`autoDispose`** per
      doc 10a's provider rule.
- [ ] `lib/database/daos/report_dao.dart` — new, read-only. Two queries. Post-doc-14
      this is a Supabase query module like the rest.
- [ ] `lib/app.dart` — `/reports/weekly` and `/reports/weekly/:weekStart`. Drawer
      **REPORTS** entry, per [doc 10b](10b-navigation.md).
- [ ] Role gate: hidden for `staff`, consistent with doc 14's matrix. Gate on
      `currentRoleProvider` (introduced inert in [doc 10b](10b-navigation.md), made
      live by doc 14), and rely on RLS as the actual boundary.
- [ ] Settings tile in `lib/screens/settings/settings_screen.dart` — **Weekly
      Report**: on/off toggle and the recipient email, with the tile summary showing
      current state ("On · owner@example.com", or "Off") in the style doc 10b sets for
      every settings tile.
- [ ] No push notification, no launch-time interstitial. A new report is a row in the
      archive and an email; nothing in this app should interrupt a morning.

### Tests

- [ ] `test/weekly_report_test.dart` — payload builder against a seeded fixture week:
      totals match the dashboard's own aggregates **exactly**, truncated lists sum to
      their block totals, and the size assertion trips on an oversized fixture.
- [ ] Validator tests — a narrative containing an unknown placeholder is rejected; a
      narrative containing a bare `24,680` typed by the model is rejected; a correct
      narrative substitutes cleanly.
- [ ] **No test calls the live API.** Model responses are fixtures. A weekly job with
      a network dependency in its test suite is a test suite that gets skipped.

## Success criteria

- [ ] Every figure in a generated report is byte-identical to the same figure on the
      dashboard for the same week. Check all of them on the first report; a single
      mismatch means the aggregate is duplicated rather than shared.
- [ ] A narrative in which the model typed a literal number is **rejected**, not
      published — verified by a deliberately poisoned fixture response.
- [ ] A narrative containing an invented placeholder is rejected — same method.
- [ ] Payload for a real week is under **12 KB** and under **4,000 input tokens**,
      measured, not estimated.
- [ ] Recorded `cost_usd` for a real report is under **$0.10**.
- [ ] End-to-end run completes in under **60 seconds** from cron fire to email sent.
- [ ] A forced model failure produces `status = 'failed'`, **no email**, and an
      in-app row with a working Retry.
- [ ] A week with zero orders produces `status = 'skipped'`, no model call, and
      `cost_usd = 0`.
- [ ] Turning the report off in settings stops both the email and the model call —
      verified by the absence of a `weekly_reports` row, not by the absence of an
      email.
- [ ] A staff JWT querying `weekly_reports` directly gets nothing. Verified against
      the API, not by checking that the UI hides it, exactly as doc 14 requires.
- [ ] Re-running the function for a week already reported updates that week's row and
      does not create a second one.
- [ ] The `ANTHROPIC_API_KEY` string does not appear anywhere in the built APK.
      `strings` the release binary and grep it; do this once and record that it was
      done.

## Notes

- The recommended actions are the part that will be judged. If after a month they
  read as generic — "focus on your top products" — the fix is the prompt and the
  payload's shape, not the model tier. Give it the concentration figures and the
  overdue list and it has something specific to say; give it totals and it will write
  a horoscope.
- `payload` in the table is the debugging tool for exactly that. Read four weeks of
  stored payloads before rewriting the prompt.
- This is the first component in the project that costs money per run. `cost_usd` is
  a column for that reason: at ₹6 a week nobody will look, but a prompt change that
  makes it ₹60 should be visible without anyone opening the Anthropic console.
- If a second report cadence is ever wanted (monthly, quarterly), it is the same
  function with a different window and a different `period` block. Do not build it
  until the weekly one has been read for two months.
