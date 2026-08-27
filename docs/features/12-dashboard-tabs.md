# 12 — Dashboard tabs + reports

| | |
|---|---|
| **Target version** | `1.14.0+18` |
| **Type** | Feature |
| **Schema** | No change |
| **Requires** | [07](07-ledger-statements.md) and [11](11-counter-stock.md) for their data |
| **Status** | **Outline** — expand action items before starting |

## Why

The dashboard is one long scroll. With ledger data (docs 05–07) and stock data
(doc 11) added, it becomes an unreadable one. Splitting it into four tabs is the
minimum change that keeps it usable.

**Re-home the existing widgets. Build no new charts** — except the one the counter
stock data genuinely requires.

| Tab | Contents |
|---|---|
| **Sales** | `PulseCard`, `RevenueMixCard`, `WeekdayHeatmapWidget` |
| **Products** | `CategoryScorecardsWidget`, `ProductLeaderboardCard`, + new counter waste / sell-through card |
| **Shops** | `ShopConcentrationCard`, + Outstanding Receivables (from doc 07) |
| **Alerts** | `AttentionFlagsWidget` |

## Outline of work

- `lib/screens/dashboard/dashboard_screen.dart` — a `TabBar` over the four tabs above.
- `lib/providers/dashboard_settings_provider.dart` — per-tab visibility toggles replace
  today's flat section list. Migrate existing saved preferences rather than resetting
  them.
- New counter waste / sell-through card, sourced from doc 11's `watchStockRange`.
  This is the only new chart in this release.
- Lazy-build tabs — only the visible tab's providers should execute. With four tabs of
  aggregates, eager building would make this release a performance regression, which is
  the opposite of the point.
- Drawer **REPORTS** section becomes live (see [doc 10b](10b-navigation.md)):
  Daily Sales · Product Movement · Counter Stock · Shop Ledger · Outstanding.
- Re-apply doc 04's discipline to any query added here: no N+1, no duplicated aggregate
  across two cards, shared providers keyed on the range.

## Success criteria

- [ ] Each tab renders in under 400 ms on the real dataset.
- [ ] No dashboard widget appears on more than one tab.
- [ ] Switching tabs does not re-execute the previous tab's queries.
- [ ] Opening the dashboard executes only the first tab's queries.
- [ ] Existing dashboard visibility preferences survive the upgrade.
- [ ] Every figure matches `1.13.0` on the same dataset — this is a re-homing, so any
      changed number is a bug.
- [ ] Waste / sell-through card reconciles with the counter stock screen for the same
      period.
