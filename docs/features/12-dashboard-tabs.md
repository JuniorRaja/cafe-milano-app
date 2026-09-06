# 12 — Dashboard tabs + reports

| | |
|---|---|
| **Target version** | `1.13.0+17` |
| **Type** | Feature |
| **Schema** | No change |
| **Requires** | [07](07-ledger-statements.md) for its data, [10c](10c-screen-restyle.md) for migrated screens |
| **Absorbs** | Lifecycle audit **Phase 4** — Riverpod modernisation |
| **Status** | **Outline** — expand action items before starting |

## Why

The dashboard is one long scroll. With ledger data (docs 05–07) added it becomes an
unreadable one. Splitting it into four tabs is the minimum change that keeps it usable.

**Re-home the existing widgets. Build no new charts.** With counter stock dropped, the
one new chart this doc used to justify is gone with it — this release puts nothing on
screen that was not already there.

It also absorbs **Phase 4** of [`docs/flutter-lifecycle-audit.md`](../flutter-lifecycle-audit.md),
because the two are the same work seen from two directions. Tabs need per-tab lazy
providers; Phase 4 needs the fourteen dashboard `FutureProvider`s converted to streams so
the hand-maintained `_refreshDashboard` invalidation list can be **deleted rather than
extended**. Doing them separately means touching every dashboard provider twice.

| Tab | Contents |
|---|---|
| **Sales** | `PulseCard`, `RevenueMixCard`, `WeekdayHeatmapWidget` |
| **Products** | `CategoryScorecardsWidget`, `ProductLeaderboardCard` |
| **Shops** | `ShopConcentrationCard`, + Outstanding Receivables (from doc 07) |
| **Alerts** | `AttentionFlagsWidget` |

## Outline of work

- `lib/screens/dashboard/dashboard_screen.dart` — a `TabBar` over the four tabs above.
- `lib/providers/dashboard_settings_provider.dart` — per-tab visibility toggles replace
  today's flat section list. Migrate existing saved preferences rather than resetting
  them.
- **Phase 4 — retire `_refreshDashboard`.** Convert the fourteen dashboard
  `FutureProvider`s to `StreamProvider`s over Drift `watch*` queries, matching the rest of
  the app. `dashboard_dao.dart` gains `watch` variants alongside its `get` ones. If an
  aggregate proves too expensive to stream, keep it a `FutureProvider` but make it depend
  on a cheap watched revision provider — the dependency graph does the invalidating, not a
  list a human has to remember to extend.
- **Phase 4 — `StateNotifier` → `Notifier`.** `DashboardSettingsNotifier` becomes an
  `AsyncNotifier`: no default-state flash, no null `_prefs`, no silently dropped write.
  `DashboardRangeNotifier` becomes a `Notifier`.
- Lazy-build tabs — only the visible tab's providers should execute. With four tabs of
  aggregates, eager building would make this release a performance regression, which is
  the opposite of the point.
- Drawer **REPORTS** section becomes live (see [doc 10b](10b-navigation.md)):
  Daily Sales · Product Movement · Shop Ledger · Outstanding.
- Re-apply doc 04's discipline to any query added here: no N+1, no duplicated aggregate
  across two cards, shared providers keyed on the range.

## Success criteria

- [ ] Each tab renders in under 400 ms on the real dataset.
- [ ] No dashboard widget appears on more than one tab.
- [ ] Switching tabs does not re-execute the previous tab's queries.
- [ ] Opening the dashboard executes only the first tab's queries.
- [ ] Existing dashboard visibility preferences survive the upgrade.
- [ ] Every figure matches `1.12.0` on the same dataset — this is a re-homing, so any
      changed number is a bug.
- [ ] `_refreshDashboard` no longer exists, and writing an order from Order Entry updates
      a visible Dashboard card with no user action. This is Phase 4's done-when.
