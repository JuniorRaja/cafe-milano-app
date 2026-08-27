# 08 — Digit-wheel quantity entry + haptics

| | |
|---|---|
| **Target version** | `1.9.0+11` |
| **Type** | Feature |
| **Schema** | No change |
| **Requires** | Nothing |
| **Status** | Done |

Shipped as `1.9.0+11`, not the `1.11.0+15` originally planned in
[roadmap.md](../roadmap.md) — this landed ahead of 10a/10b/10c/06, taking the next
free build number rather than its pre-assigned one. Build numbers are assigned at
ship time, not reserved in advance; see roadmap.md for the reconciliation.

## Why

The highest-frequency interaction in the app: 15+ shops × ~6 products, every day.
Two facts from the real dataset drive the design:

- **90% of quantities are multiples of 5**, median 10. Reaching 10 currently takes
  ten taps on the `+` stepper, or a tap-through to a keyboard sheet.
- **Only ~6 of 28 products** carry a non-zero quantity on an average order, so the
  screen presents 28 equally-weighted rows when 6 matter.

The fix is to make exact entry cheap, through two paths that each do one thing:

- **Tap the number** → a **three-digit wheel** replaces the number keyboard. Any
  quantity is at most three short rolls, nothing is covered by a keyboard, and it
  works one-handed with a thumb. Because 90% of quantities end in 0 or 5, most
  entries touch the tens wheel and nothing else.
- **Long-press ±** for a repeating ±5 in the list, for bumping a quantity without
  opening anything. The ±1 steppers keep their single-tap behaviour for corrections.

A **horizontal swipe on the row was considered and rejected** (2026-08-27): the screen
is a vertical list used at 5 a.m. under time pressure, and a gesture that fires by
accident silently changes an order quantity. Every remaining path is deliberate — a
tap, a long press, or a wheel roll. The 2026-08-19 decision to keep a **flat list**
rather than a "usual items" shortlist also stands; product emphasis is expressed
through visual weight instead.

A first pass shipped wheel-only, no keyboard. Real-device testing the same day
(2026-08-27, Samsung Galaxy, Android 16) surfaced four corrections, folded into the
sections below rather than left as a separate changelog:

- The three wheels stretched to fill the sheet's full width — far wider than a single
  digit needs. Fixed at a narrow column width instead.
- `selectionClick` (wheel ticks, long-press repeat) and `mediumImpact` (Confirm Order)
  were not felt on the test device. Bumped a notch each: `lightImpact` and
  `heavyImpact`. This may partly be the device's own haptics setting rather than pure
  code, but there is no stronger constant to reach for, so the fix is what's testable.
- 150 ms between long-press repeat ticks reacted faster than a thumb can track.
  Slowed to 400 ms.
- **The keyboard fallback is back**, as a `Wheel` / `Input` tab inside the sheet
  rather than the sheet's only mode. This also quietly retires the "known ceiling"
  below — nothing above 999 needs a fourth wheel now, it just needs the Input tab.

## Action items

### Quantity sheet — three-digit wheel + Input tab

Replaces the `TextField` + `− / +` pair inside `_QtyEditSheet` in
`lib/widgets/product_qty_row.dart` with a `SegmentedButton<bool>` choosing between two
sub-modes, `Wheel` (default) and `Input`.

- [ ] Three `CupertinoPicker`s in a `Row`, hundreds · tens · ones. From
      `package:flutter/cupertino.dart` — **no new dependency**. `childCount: 10` each,
      built via `CupertinoPicker.builder`.
- [ ] Each wheel is a fixed, narrow column (`SizedBox(width: 56)`), not `Expanded` —
      a digit does not need a third of the sheet's width. Centered as a group in the
      `Row`, not stretched to it.
- [ ] `CupertinoPicker.builder` with a finite `childCount` is non-looping by default
      (`looping` is only a parameter on the plain `CupertinoPicker(children: …)`
      constructor) — do not reach for the other constructor to add it. Looping wheels
      do **not** carry: with wrap on, 90 plus one tick on the tens wheel silently
      becomes 0. Bounded 0–9 wheels make the ceiling visible instead of surprising.
- [ ] Each wheel gets a `FixedExtentScrollController` seeded from the corresponding
      digit of `initialQty`, so the sheet opens on the current quantity.
- [ ] Wheel value is composed on confirm: `h * 100 + t * 10 + o`. No clamp code
      needed — the range is the wheels.
- [ ] `HapticFeedback.lightImpact()` in each `onSelectedItemChanged`.
      `CupertinoPicker`'s built-in tick haptic is **iOS-only**; without this, Android
      gets a silent wheel. `selectionClick` was tried first and was not felt on a
      physical Android device — see the note above.
- [ ] Leading zeros render as-is (`0 1 0` for ten). Odometer convention, no special
      casing.
- [ ] `Input` tab is the pre-wheel `TextField` + digits-only `inputFormatter`,
      clamped 0–9999 — the full range, not capped at 999 like the wheel. This is the
      only path for a quantity above 999; the wheel doesn't need a fourth digit
      because of it.
- [ ] Switching tabs carries the value across: `Wheel → Input` seeds the text field
      from the composed digits; `Input → Wheel` reseeds the three wheels from the
      parsed (and 0–999-clamped) text, forcing a fresh `FixedExtentScrollController`
      via a `ValueKey` bump — a `CupertinoPicker` does not re-jump on its own when
      its `initialItem` changes under an existing controller.

### Long-press repeat

- [ ] `_StepperBtn` gains `onLongPress` → `Timer.periodic(400ms)` repeating ±5 until
      release, clamped 0–9999. 400 ms, not the original 150 ms — 150 ms fired faster
      than a thumb can track on a real device. Cancel the timer in `dispose` — a
      leaked periodic timer here will keep mutating quantities after the row is gone.
- [ ] Single tap stays ±1. The long press is the only fast path left in the list, so
      it has to be reliable on the first try.
- [ ] Unpriced products already pass null callbacks, so the steppers are inert for
      them and the long press inherits that. Nothing extra to build.

### Haptics pass

- [ ] `lightImpact` on each wheel tick and on each ±5 from long-press repeat.
      (Originally `selectionClick`; bumped after it wasn't felt on a physical
      device — see the note above.)
- [ ] `heavyImpact` on Confirm Order. (Originally `mediumImpact`, same reason.)
- [ ] `lightImpact` on ±1 already exists — leave it. It now matches the wheel/repeat
      tick intensity; the distinction that mattered (felt vs. not felt) trumps the
      original escalation-by-action-weight idea.
- [ ] Principle: haptics replace confirmation toasts for reversible actions. Do not
      add a snackbar for anything that now has a haptic.

### Visual weight

- [ ] Zero-quantity rows render at reduced visual weight; non-zero rows get a filled
      quantity chip. No reordering — the list stays alphabetical and stable, because a
      list that reorders under your thumb while you are entering an order is worse
      than a long one.

### Tests

- [x] Digit composition: wheels seeded from 250, 5, and 999 each read back unchanged.
      See `test/product_qty_row_test.dart`.
- [x] Long-press repeat: holding fires more than one tick and stops on release; no
      pending `Timer` after the widget is disposed mid-hold. Same file.
- [x] Input tab: typing 5000 and confirming directly preserves the full value;
      typing 5000 then switching to Input → Wheel clamps to 999, not silently to
      something else. Same file.

## Success criteria

- [ ] Entering a realistic 6-product order takes **zero keyboard** and no more than
      three interactions per product, using the default Wheel mode.
- [ ] Setting 250 from 0 takes two wheel rolls and no typing.
- [ ] The sheet always opens in Wheel mode, seeded on the row's current quantity, not
      0. Switching to Input and back carries the value, it does not reset it.
- [ ] The wheel column is a single narrow strip per digit, not a third of the sheet.
- [ ] The wheel ticks and Confirm Order are both felt on a physical Android device,
      not just conceptually correct in code.
- [ ] Long-press repeat is comfortably followable — roughly 2–3 ticks per second, not
      a blur.
- [ ] Switching to the Input tab pops the keyboard and accepts up to 4 digits; nothing
      above 999 is unreachable.
- [ ] Long-press repeat stops immediately on release and leaves no timer running after
      navigating away.
- [ ] Scrolling the product list never changes a quantity — no gesture on the row
      itself mutates data.
- [ ] Both remaining input paths still work: ±1 steppers (tap and long press), and
      tap-the-number → Wheel/Input sheet.
- [ ] Confirm Order is reachable and correct with a mix of stepper-entered,
      wheel-entered, and input-entered quantities.
