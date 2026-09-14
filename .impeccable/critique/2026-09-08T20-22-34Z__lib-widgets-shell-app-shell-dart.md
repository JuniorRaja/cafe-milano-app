---
target: the navigation system (bottom bar, drawer, shell header)
total_score: 29
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 2
target_identity: "file:E:\\My Works\\cafe-milano-app\\lib\\widgets\\shell\\app_shell.dart"
target_fingerprint: "sha256:6413864f987100011dabfe9145e6b533a40032c6c04fdcb0480212d0329ebf75"
target_path: "E:\\My Works\\cafe-milano-app\\lib\\widgets\\shell\\app_shell.dart"
timestamp: 2026-09-08T20-22-34Z
slug: lib-widgets-shell-app-shell-dart
---
Method: dual-agent (A: design review · B: deterministic source evidence)
Target: the navigation system — bottom bar (`FloatingNavBar`), drawer (`AppDrawer`), shell (`AppShell`), header idiom (`AppScaffold`). Flutter → Android, Material 3, Operate mode.

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | While the bar is slid away on scroll-down there is no persistent "which tab am I on" cue anywhere on screen. |
| 2 | Match System / Real World | 3 | One thing carries three names — caption `MONEY`, drawer group `Money`, item `Ledger`; "Price Matrix" is jargon for "what I charge each shop". |
| 3 | User Control and Freedom | 4 | Back from a drawer push returns to the origin tab; tap-again resets a branch; hamburger + edge-swipe both open the drawer. Only tax: a hidden bar needs a scroll reversal to recover. |
| 4 | Consistency and Standards | 2 | Three core Material conventions each replaced bespoke: `NavigationBar` → custom `Row`, `AppBar` → custom `Column`, "bottom nav stays put" → hide-on-scroll. Bar is 62 dp vs the M3 80 dp spec. Internally consistent, platform-divergent. |
| 5 | Error Prevention | 4 | Unshipped destinations hidden not disabled; `destinationForLocation` longest-prefix match stops nested routes mis-highlighting. |
| 6 | Recognition Rather Than Recall | 3 | `Price Matrix` is filed under `Money` next to Ledger, not under `Catalogue` next to Shops/Products where someone onboarding a shop's pricing would look. |
| 7 | Flexibility and Efficiency | 2 | No accelerators in the shell. Every visit to Price Matrix or a master is a full drawer traversal (~3 taps + scan). The removed centre FAB took the only quick-add with it. No pinned/recents block. |
| 8 | Aesthetic and Minimalist Design | 3 | Bar and drawer are calm and grouped, but the drawer restates all five bottom-bar destinations — a second front door to the same five rooms. |
| 9 | Error Recovery | 3 | Outstanding card has an explicit `'Outstanding unavailable'` fallback. Little else nav-relevant to diagnose. |
| 10 | Help and Documentation | 2 | Discovery of everything behind the hamburger depends on the user opening it once, unprompted; a code comment concedes the edge-swipe is "a feature only the person who built it knows". No first-run coaching, no slot tooltips, the "order of the day" framing is never stated to the user. |
| **Total** | | **29/40** | **Good (low end) — Consistency and Flexibility are the two axes dragging it down, both fixable without touching the IA.** |

## Design Specificity Verdict

**Authored for the bakery day in its model; category-interchangeable in its chrome.**

**Design review:** The *ideas* could only come from watching this business run. The bottom bar is a left-to-right timeline of the working day — see (`Overview`) → enter (`Orders`) → bake (`Kitchen`) → bill (`Billing`) → collect (`Ledger`) — and that ordering is a tested contract (`bottomBarRoutes` index 0–4 == branch order in `app.dart`, pinned by `routing_test.dart`). A generic app sorts nav by frequency or parks Settings in the bar; this one encodes a process. The pinned Outstanding card puts a live receivables figure permanently in the navigation, closing the audit's "all-shops outstanding is not buried, it's *absent*" finding at the nav layer. `shipped:false` hides unbuilt destinations rather than greying them.

But the *construction* re-creates Material plumbing without the specificity reaching the pixel. `FloatingNavBar` is a hand-rolled `Row` of `InkWell`s that renders as a plain Material bar **minus the selection indicator**. `AppScaffold._Header` is a bare `Column` of `Text` that renders as an `AppBar` **minus the heading semantics**. The product thinking is in the data model and the ordering; the chrome is a slightly weaker restatement of the components it replaced.

**Deterministic scan:** `impeccable detect` is N/A for Flutter source (markup scanner) and there is no browser target, so no CLI/overlay evidence. Source-evidence pass confirms:
- **Bottom bar:** no `NavigationBar`/`BottomNavigationBar`. `Container` → `SizedBox(height: 62)` → `Row` → `Expanded(_Slot)` where `_Slot` = `Material` + `InkWell` + `Column(Icon 22, Text caption)`. Mounted as a `Positioned` + `AnimatedSlide` overlay, not `Scaffold.bottomNavigationBar` (a test asserts the slot is null).
- **Drawer:** `Drawer` + custom `_DrawerRow` (`Material`+`InkWell`+`Row`). No `NavigationDrawer`/`NavigationDrawerDestination`.
- **Header:** custom `Column`/`Row`. No `AppBar`/`SliverAppBar`. Class doc: "Replaces 5 hand-rolled headers **and** 15 `AppBar`s."
- **Accessibility primitives (app-wide):** `Semantics(` used **2×** total (one is the nav slot, one is `status_badge`). `header: true` = **0**. `MergeSemantics` / `semanticLabel` / `liveRegion` = 0. `tooltip:` = 22. The nav slot sets `Semantics(selected, button, label)` but not `excludeSemantics`, so the inner `Text` stays a separate node; no container role, no "N of 5" position. Drawer rows have **no `Semantics` wrapper at all** — `active` is colour-only, never exposed as `selected: true`.
- **Touch targets:** bottom-bar slot 62 dp ✓. Drawer row hit area ≈ **44 logical px** (icon 20 + inner vertical padding 12+12) — below the 48 dp Material minimum. Header/`ShellDrawerButton` `IconButton`s are default 48 ✓ and carry tooltips.
- **Token compliance:** `tool/check_tokens.sh` passes at 0, but it only greps `Colors.grey` / `fontSize:<n>` / `BorderRadius.circular(`. The nav files still carry untokened literals it doesn't see: `Radius.circular(24)` ×2 (drawer shape), `Colors.white24` / `Colors.white10` (drawer divider + card fill), `height: 62.0` (bar), `width: 296` (drawer), icon `size: 20/22`, `SizedBox(height: 2)`.
- **Reduced motion:** honoured — `AppShell` gates the `AnimatedSlide` on `disableAnimationsOf` (re-read every build) and `FloatingNavBar` skips its entrance transition (read once in `didChangeDependencies`, so an OS toggle mid-session leaves the two disagreeing). A test asserts the bar stays put under reduced motion.
- **Tests:** routing (31), navigation (2), shell (9), nav-bar-scroll (7), branch-scroll (3), order-entry-nav (3) — all pass. The IA is genuinely well-covered.

**Visual overlays:** none — native target, no browser injection possible.

## Overall Impression

The navigation's *model* is the best thing about this app's design: a five-step day encoded as a tested contract, one data source feeding every surface, a money figure living in the chrome. The *rendering* of that model spends real engineering re-building `NavigationBar`, `AppBar` and `NavigationDrawer` and lands each one a notch below the original — no selection pill, no heading semantics, no `selected` announcement, a sub-48 drawer target. The single biggest opportunity: stop hand-rolling the three components, theme the real ones to the look you want, and get the indicator, state layers, tab semantics and inset handling back for free — without touching the day-order IA that works.

## What's Working

1. **The bar is a tested process contract, not just chrome.** `bottomBarRoutes` index 0–4 == the shell branch order == the physical order of the bakery's day, asserted by `routing_test.dart`. Navigation doubles as a checklist the baker follows without deciding anything. Real product-specific IA.
2. **One data model feeds three surfaces.** `destinations.dart` drives the drawer, the bar and settings search; `shipped:false` hides unbuilt destinations instead of greying them. Adding a destination is one row (AGENTS rule 12), no "coming soon" dead ends, no drift between surfaces.
3. **The pinned Outstanding card turns the nav into a status surface.** A live receivables figure permanently in navigation, with a real error fallback — fixing "all-shops outstanding is unreachable" at the navigation layer rather than with another screen.
4. **The fiddly `StatefulShellRoute` details are correct and tested.** Back-from-push returns to the origin tab, tap-again resets a branch to root, per-branch scroll resets on exit not entry.

## Priority Issues

### [P1] Custom bottom bar has no selection indicator — "you are here" rides on colour + icon-fill only
**Why it matters.** `_Slot` swaps `brandDeep` ↔ `textTertiary` and outlined ↔ filled icon. Both colours are legible, but the *difference* is a value/saturation shift, not a shape — at a glance, one-handed, in low light, the only reliable "current tab" is the outline-vs-fill of a 22 px glyph. Material's `NavigationBar` pill indicator is a spatial cue that survives low attention; it also brings bounded state layers and "tab N of M" semantics the hand-rolled slot lacks. This is a WCAG 1.4.1 (use-of-colour) smell.
**Fix.** Add a real indicator behind the selected slot's icon — a `brandPrimary`-tinted pill or a 2.5 px top edge, animated on selection — and keep the icon-fill as the second channel. Then seriously weigh migrating to a themed `NavigationBar`: the file's stated reasons for going custom (solid bar not floating pill, labels always shown, rounded top, 62 dp) are all reachable through `NavigationBarThemeData` + `NavigationBar(height:)`, and you get the indicator, state layers, inset handling and tab-set a11y for free.
**Suggested command.** `/impeccable shape` (decide custom-with-indicator vs `NavigationBar` migration, then build it).

### [P1] Drawer-only destinations have no accelerator, and Price Matrix is mis-grouped
**Why it matters.** `Price Matrix` is config you touch when onboarding a shop or changing a rate. Each visit: hamburger → scan 4 group headers → tap. It sits under `Money` next to `Ledger`, not under `Catalogue` next to `Shops`/`Products` where someone setting up a shop's pricing would look — recognition fails, it becomes recall plus a hunt. The three masters (Shops, Products, Categories) have the same shape: no pin, no recents, no shell-level search.
**Fix.** Regroup `Price Matrix` under `Catalogue`, *and/or* add a "Prices" entry point from the Shops and Products screens (a section-header `View all` or a row action) so it's reachable where it's needed. Consider a pinned/recents block at the top of the drawer for the 3–4 most-used drawer destinations.
**Suggested command.** `/impeccable layout`.

### [P2] Hide-on-scroll removes the primary nav and the only persistent location cue
**Why it matters.** Hiding a bottom nav on scroll is top-app-bar behaviour, not bottom-nav behaviour. On the 18-shop Orders list the baker scrolls down to scan, finishes, and the next step (`Kitchen`) is off-screen — recovery needs an upward scroll or hitting the list end. One-handed at 5 a.m. that's a real stumble, and while hidden there is *no* on-screen indication of the current tab. Reduced-motion correctly keeps it pinned, which is a tacit admission the movement is marginal.
**Fix.** Question whether a 5-slot 62 dp bar needs to hide on a phone at all. If it stays: keep a collapsed ~4 px strip carrying the active indicator so location is never fully lost, and restore the full bar on scroll-idle after a short delay (today `idle` deliberately does *not* restore it).
**Suggested command.** `/impeccable animate`.

### [P2] The custom header has no heading semantics — and it's the idiom on ~20 screens
**Why it matters.** `AppScaffold._Header` emits two unlabelled `Text` nodes. A screen reader gets no level-1 heading for any screen in the app, and the caption ("MONEY", "TODAY", but also "GOOD MORNING" on the dashboard) is announced as an orphan string. 20 screens depend on this one idiom, so the gap is app-wide, not local to nav.
**Fix.** Wrap the title in `Semantics(header: true)`; merge caption + title into one label ("Ledger, Money") or `excludeSemantics` the caption; assert every caller-supplied `leading` carries a tooltip (the hamburger and auto-back-arrow do; a custom `leading` might not).
**Suggested command.** `/impeccable harden`.

### [P2] Drawer rows aren't a `NavigationDrawer` — no `selected` semantics, ~44 px target, active = colour only
**Why it matters.** `_DrawerRow` has no `Semantics` wrapper; the active destination is conveyed only by `Material.color` and text colour, never exposed as `selected: true`, so a screen-reader user cannot tell which item is current. The InkWell hit area computes to ≈ 44 logical px (icon 20 + 12 + 12), below the 48 dp Material minimum, on the app's main wayfinding surface.
**Fix.** Move to `NavigationDrawer` + `NavigationDrawerDestination` (built-in `selected` semantics, 56 dp targets, the cream active-pill for free), *or* keep the custom row but add `Semantics(selected: active)` and raise the inner vertical padding from `AppSpace.s3` to `AppSpace.s4` (→ ≈ 52 px).
**Suggested command.** `/impeccable harden`.

## Persona Red Flags

**Alex (power user).** No accelerators exist in the shell. `Price Matrix` and the three masters are a full drawer traversal every time — no pin, no recents, no search from the shell. The removed centre FAB deleted the only quick-add, so "new order" is now Orders tab → scan list → tap a shop, and the bar can't shortcut it. `tap-again-to-reset-branch` is real but undocumented and undiscoverable. Hide-on-scroll actively fights fast scrolling.

**Jordan (first-timer).** `ShellDrawerButton` gives zero scent of the 6+ destinations behind it — the code comment concedes this. The five bar icons (`insights`, `edit_note`, `restaurant`, `receipt_long`, `account_balance_wallet`) are near-identical rectangles-with-lines, and the "order of the day" framing that makes them cohere is never shown to the user. `Ledger` and `Price Matrix` are terms a new user won't map to "who owes me" and "what I charge each shop". No first-run overlay anywhere.

**Casey (distracted, one-handed — the 5 a.m. baker).** The `AnimatedSlide` bar means the nav target they're reaching for is frequently not where it was a second ago. The selected-tab cue is a subtle colour shift, unusable at a glance in motion. The drawer is a 296 px left-anchored panel whose header, rows and the hamburger that opens it are all top-left — the hardest reach for a right thumb — and the pinned Outstanding card + version footer push `Settings` around vertically depending on group contents.

## Minor Observations

- **Two animation systems own the same bar** — `AppShell`'s `AnimatedSlide` for hide/show, `FloatingNavBar`'s own 450 ms `AnimationController` for the entrance fade+slide. Consolidate.
- **`_Slot` has no `tooltip`** — long-press on a Material `NavigationDestination` shows the label; here it does nothing. TalkBack loses the hint.
- **Slot semantics lack set membership** — `Semantics(button, selected)` with no `inMutuallyExclusiveGroup`, no position/count. A screen reader says "selected, button", not "tab 2 of 5".
- **Caption casing is inconsistent** — `_Header` upper-cases the caption; most screens pass a noun ("Money", "Kitchen") but the dashboard passes `greetingFor()` → "GOOD MORNING".
- **`bottomBarDestinations` isn't visibility-filtered** — `firstWhere` over `appDestinations`, not `visibleDestinations`; safe today, throws the day someone sets a bar route `shipped:false`.
- **Reduced-motion is read once in `FloatingNavBar`** (`didChangeDependencies` + `_scheduled` guard) but every build in `AppShell` — toggling the OS setting mid-session leaves the two disagreeing.
- **The drawer restates all five bottom-bar destinations** — opening the drawer to reach Orders/Kitchen/Billing/Ledger is a slower path to a place one tap away, and it runs a second "selected" computation (`destinationForLocation` longest-prefix) that can drift from `navigationShell.currentIndex` on nested routes.
- **Untokened magic numbers the ratchet doesn't catch** — `Radius.circular(24)` ×2, `Colors.white24`/`white10`, `height: 62.0`, `width: 296`, icon `size: 20/22`, `SizedBox(height: 2)` (not `AppSpace.s1`).
- **62 dp bar vs 80 dp M3 spec** — fine as a density choice, but verify icon(22) + 2 + caption(~13) fits at the largest text scale.

## Questions to Consider

1. If the bar is "the order of the day," why does the app open on **Overview** — the one slot that isn't a step in that day? Should cold start land on `Orders`?
2. What does the hand-rolled bar actually buy you over a themed `NavigationBar`, beyond 18 dp less height? If the honest answer is "the look," can `NavigationBarThemeData` deliver that look and hand back the indicator, state layers and tab semantics?
3. Is **Kitchen** a navigation destination or a daily artefact you generate once and share? If you look at it for 20 seconds a day, has it earned a permanent slot that `Shops` or `Price Matrix` could use — or is the bar's value precisely that it's the *sequence*, not the *frequency*?
4. The drawer contains everything the bar contains, plus more. Is it a complete map (good) or a second front door to the same five rooms (noise)? What breaks if the drawer only holds what the bar doesn't?
5. Should the pinned Outstanding figure live in a drawer the user has to *decide* to open — or on Overview, which they see on every cold start anyway?
6. The bar is at 5 of 5 slots with docs 15 and 16 already committed as new top-level destinations. When the 6th daily destination arrives, what gives — a slot, or the whole "one bar = the day" idea?
