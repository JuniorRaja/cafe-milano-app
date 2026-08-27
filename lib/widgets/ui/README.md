# The component kit

One import: `import '../../widgets/ui/ui.dart';` — it re-exports the tokens too.

**The rule: new UI composes from this kit, not from `Container`.** If you find
yourself writing `BoxDecoration`, a `fontSize:`, or a colour, you are building a
component. Either an existing one fits, or the kit is missing one and it belongs
here rather than in a screen.

## Which component

| You want to… | Reach for |
|---|---|
| Give a screen a header | `AppScaffold` |
| Put content on a white ground | `AppCard` |
| Summarise a list before it is scrolled | `StatBand` |
| Show the one big figure on the screen | `HeroStatCard` |
| Let the user narrow a list | `FilterChipRow` |
| Title a group of rows | `SectionHeader` |
| Draw a row in a list | `ListRow` |
| Say what something *is* — Pending, Overdue | `StatusBadge` |
| Say what changed — `↑8%`, `−₹120` | `DeltaPill` |
| Show four columns of numbers inside a card | `MiniTable` |
| Explain *why* | `NoteBanner` |
| Offer an action | `AppButton` |
| Have nothing to show | `EmptyState` |
| Be waiting for data | `AppSkeleton` |

## Rules that are easy to get backwards

- **Brand colour never carries meaning.** Gold is emphasis, not "good". A figure
  that is up is `AppTone.positive`, never gold.
- **Semantic colour is never decorative.** If a row is red, something is wrong
  with it. This only holds if it holds everywhere.
- **`FontWeight.bold` is banned.** Weight comes from an `AppType` step.
- **`EmptyState` requires an action.** `EmptyState.inert` exists for the genuine
  exception — a past date with no orders — and is the exception.
- **No brand string is written out.** App name, short name, tagline, logo and
  currency symbol come from `ref.watch(brandProvider)`.
- **Money goes through `BrandConfig.money`** (`lib/utils/money.dart`). Indian
  digit grouping is a real formatting difference, not a symbol swap.
- **No `Theme.of(context).brightness` check.** There is no dark mode, and a
  half-built one is worse than none.

## Layout vocabulary

`AppSpace.s1..s6` (4·8·12·16·24·32) for every gap and pad.
`AppRadius.rS/rM/rL/rFull` for every corner.
`AppShadow.card/raised` for every shadow — Material `elevation:` is not used.

## Where the values live

`lib/theme/tokens.dart` is the only place a colour, size, radius or shadow is
defined. `lib/theme/app_theme.dart` wires them into `ThemeData`.
`lib/theme/brand_config.dart` is the seam the white-label release (doc 17) will
pull on. `tool/check_tokens.sh` fails if anything in this folder defines a value
of its own.
