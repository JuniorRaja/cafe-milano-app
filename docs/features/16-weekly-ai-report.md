# 16 — Weekly AI report

| | |
|---|---|
| **Target version** | `2.2.0+20` |
| **Type** | Feature |
| **Schema** | No change. Reports are JSON files, not database rows |
| **Requires** | [12](12-dashboard-tabs.md) for the aggregates |
| **Status** | Ready |

## What this is

The dashboard answers questions the owner already knows to ask. Nothing in the app tells
him something he was not looking for.

One page, once a week, in plain sentences: what moved, and what to do about it. "Bread
revenue fell 14% this week, all of it at the three Adyar shops" is something the owner
would act on and will never spot on a heatmap.

It runs **on the phone**, with the owner's own Anthropic API key. No server, no schedule,
no email. The owner opens Reports and taps *Generate*.

## What the report says

- Revenue against last week — total, and per delivery day.
- Category and product movement, and the products behind it.
- Top shops by share, and any shop that moved sharply.
- Collections: billed, collected, outstanding, shops overdue past 14 days, oldest open
  bill.
- Two or three actions, each naming a shop or product and a number.

**It computes nothing new.** Every figure already exists because the dashboard computes
it. If a number is wanted that the dashboard does not have, that is a dashboard change
first and this reads it second.

## The API key

**The owner pastes their own key into Settings.** It is stored in `shared_preferences`,
which is app-private storage; Android auto-backup is already disabled, so it does not
leave the phone except in the API call itself.

The key is never in the APK, never in the repo, never in CI. That matters because this
project publishes its APKs publicly — a key compiled into the build would be readable with
`strings` in under a minute.

Consequences, accepted:

- No key, no report. The screen says so and links to where to get one.
- The owner pays Anthropic directly, about **₹5 a report** (see below).
- Reports are generated when the owner taps, not on a schedule. A phone app has no cron,
  and adding a background-job package to save one tap a week is not worth it.

## What the model gets

**A small pre-aggregated JSON summary. Never rows.** Hard limit: **12 KB**. The builder
asserts the size and fails rather than sending more.

| Block | Contents | Cap |
|---|---|---|
| Period | week start/end, days with orders, prior week | — |
| Totals | revenue, order count, shops served — this week and last | — |
| By weekday | revenue for each of 7 days, both weeks | 14 numbers |
| Categories | name, revenue, qty, change % | all (~7) |
| Products | name, category, revenue, qty, change % | top 10 by revenue |
| Shops | name, area, revenue, share %, change % | top 8 by revenue |
| Collections | billed, collected, outstanding, shops overdue > 14d, oldest open bill | — |

A week is roughly 1,300 order lines; two weeks is 2,600. Sending them loses three ways:
the model would be doing arithmetic `SUM()` already does correctly, it costs about thirty
times as much, and it is slower. The model's job is to notice, connect and phrase.
Arithmetic is not on the list.

**Truncation is by rank and never silent.** When a list is cut, the tail collapses into
one `"other"` row carrying its total, so every list still adds up to the block total the
model is also given. Percentages and week-on-week changes are **pre-computed** — the model
is never given a reason to calculate one.

## Every number must come from the payload

The model writes prose around figures it is handed. It never produces a figure.

One check, after the response comes back: **pull every digit group out of the narrative
and require each one to be in the set of figures that were sent** (formatted the same way
the prompt asked for), plus the week's date labels. Anything else fails the report.

This is an exact set-membership test, not a tolerance. `₹24,860` against a true `₹24,680`
is one transposition and reads perfectly plausible — and it is not in the set, so it
fails. A fuzzy "close enough" check would pass it.

A failed report stores the raw text. That is the artefact needed to fix the prompt.

## Model and cost

**`claude-opus-5`.** It runs 52 times a year on a 4 KB payload, so cost cannot decide it,
and the half of the output worth reading — the recommended actions — is judgement, not
summarising.

At $5 / $25 per million tokens: ~5,000 input tokens ≈ $0.025, ~1,500 output ≈ $0.037.
**About $0.06, roughly ₹5 a report, ₹260 a year.** `claude-haiku-4-5` would cost about ₹1
and lose the only thing this feature is judged on.

Request shape, so it is not rediscovered during implementation:

- `POST https://api.anthropic.com/v1/messages`, headers `x-api-key`,
  `anthropic-version: 2023-06-01`, `content-type: application/json`.
- `model: "claude-opus-5"`, `max_tokens: 4000`, `output_config: {"effort": "medium"}` — a
  4 KB payload does not need more.
- Leave `thinking` out. Adaptive thinking is on by default on this model, and
  `budget_tokens` is rejected with a 400.
- Plain text out, with the section headings named in the prompt. No structured output
  format, no assistant prefill (prefill returns a 400 on this model).
- `dart:io` `HttpClient` with a 60-second timeout, as `update_service.dart` already does.
  **No new dependency.**
- Read `usage.input_tokens` / `usage.output_tokens` off the response and store the cost.

## Where reports are stored

JSON files in the app documents directory, one per week:
`reports/2026-W37.json` — `{weekStart, weekEnd, status, payload, narrative, model,
inputTokens, outputTokens, costUsd, error, generatedAt}`.

Not a database table, because the Drift schema is frozen at v6 and a few KB a week does
not justify unfreezing it. `path_provider` is already a dependency.

The trade-off, stated: **reports are not in the backup**. If that turns out to matter,
the fix is to add the folder to `backup_service.dart`, not to add a table.

`payload` is stored, not just the narrative. Without the exact input, a wrong figure
cannot be traced to whether the SQL or the model produced it — and that is the only
question worth asking when a wrong figure appears.

## Work

### Report engine

- [ ] `lib/services/weekly_report/payload.dart` — build the summary from
      `dashboard_dao.dart` and the outstanding query from [07](07-ledger-statements.md).
      Rank truncation with the `other` row, pre-computed deltas, and the 12 KB assertion.
- [ ] `lib/services/weekly_report/prompt.dart` — the system prompt. States the rule: use
      only the figures given, copy them exactly as written, never calculate.
- [ ] `lib/services/weekly_report/client.dart` — the HTTP call, the timeout, and the
      typed errors (no key, bad key, no network, rate limited, API error).
- [ ] `lib/services/weekly_report/validate.dart` — the digit scan above.
- [ ] `lib/services/weekly_report/store.dart` — read and write the JSON files, newest
      first.

### App

- [ ] `lib/screens/reports/weekly_report_list_screen.dart` — one row per week, newest
      first: week range, headline revenue, and a marker for failed weeks. Built from the
      existing kit. **No new UI primitives.**
- [ ] The list screen offers *Generate last week's report* when last week has no report
      and there are orders in it.
- [ ] `lib/screens/reports/weekly_report_screen.dart` — one report, read as prose, with
      `SectionHeader` per section and `DeltaPill` for the week-on-week moves. Share as
      text. Money goes through `money.dart`.
- [ ] `lib/providers/weekly_report_provider.dart` — list and single-week providers, both
      `autoDispose`.
- [ ] `lib/app.dart` — `/reports/weekly` and `/reports/weekly/:weekStart`. Drawer
      **REPORTS** entry, per [10b](10b-navigation.md).
- [ ] Settings tile — paste the API key, a *Test key* button, and a *Clear key* button.
      The tile summary shows "Key set" or "No key". **Never show the key back in full.**
- [ ] A week with no orders is not sent to the model. It is written as `skipped`. Paying
      to have a model write "nothing happened" is a bug.
- [ ] A failure shows what went wrong and a **Retry**. A missing report and a failed
      report must never look the same.

### Tests

- [ ] `test/weekly_report_payload_test.dart` — against a seeded fixture week: totals match
      the dashboard's own aggregates exactly, truncated lists add up to their block
      totals, and the size assertion trips on an oversized fixture.
- [ ] `test/weekly_report_validate_test.dart` — a narrative with a number that was never
      sent is rejected; a transposed figure (`24,860` for `24,680`) is rejected; a correct
      narrative passes.
- [ ] **No test calls the live API.** Responses are fixtures.

## Skipped on purpose

| Skipped | Add when |
|---|---|
| A scheduled run, email, push | There is no server, and no background job is worth a package. Add when the owner says he keeps forgetting |
| Daily, monthly or per-shop reports | The weekly one has been read for two months |
| Follow-up questions / chat about the report | Never in this doc. One page, one direction |
| Placeholder substitution in the prompt | The digit scan catches the same errors with a tenth of the code |
| Prompt caching | 52 calls a year. The cache would expire between every one |

## Success criteria

- [ ] Every figure in a report matches the dashboard for the same week, exactly. Check all
      of them on the first report; one mismatch means an aggregate is duplicated rather
      than shared.
- [ ] A response with a number that was never sent is **rejected**, verified with a
      deliberately poisoned fixture.
- [ ] A real week's payload is under 12 KB, measured.
- [ ] Recorded cost for a real report is under $0.10.
- [ ] With no key set, the screen explains what is needed and makes no network call.
- [ ] With a wrong key, the error says the key was rejected — not "check failed".
- [ ] Airplane mode produces a clear failure and a working Retry. No crash.
- [ ] A week with zero orders is marked skipped, with no API call and no cost.
- [ ] Generating the same week twice overwrites that week's file. There is never a second
      report for one week.
- [ ] The key does not appear in any log, any share text, or the built APK.

## Notes

- The recommended actions are what this will be judged on. If after a month they read as
  generic — "focus on your top products" — the fix is the prompt and the payload's shape,
  not the model. Give it concentration figures and the overdue list and it has something
  specific to say; give it totals and it writes a horoscope.
- Read four stored payloads before rewriting the prompt.
- This is the first thing in the app that costs money per use. The stored cost is there so
  a prompt change that makes it ₹60 a week is visible without opening the Anthropic
  console.
