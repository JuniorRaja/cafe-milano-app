# 08 — Swipe-by-5 order entry + haptics

| | |
|---|---|
| **Target version** | `1.11.0+15` |
| **Type** | Feature |
| **Schema** | No change |
| **Requires** | Nothing |
| **Status** | Ready |

## Why

The highest-frequency interaction in the app: 15+ shops × ~6 products, every day.
Two facts from the real dataset drive the design:

- **90% of quantities are multiples of 5**, median 10. Reaching 10 currently takes
  ten taps on the `+` stepper, or a tap-through to a keyboard sheet.
- **Only ~6 of 28 products** carry a non-zero quantity on an average order, so the
  screen presents 28 equally-weighted rows when 6 matter.

The fix is to make **±5 the cheapest gesture** and typing the fallback, rather than
the reverse. This is additive — the existing ±1 steppers and the tap-the-number
keyboard sheet both stay.

Carried forward from the archived v5 roadmap Phase 1, unchanged in substance. The
decision to keep a **flat list** rather than a "usual items" shortlist was taken
2026-08-19 and is not reopened here; product emphasis is expressed through visual
weight instead.

## Action items

### The swipe gesture

- [ ] `lib/widgets/product_qty_row.dart` — wrap the row in a `GestureDetector`
      (`onHorizontalDragStart` / `Update` / `End`).
- [ ] Accumulate drag distance in the row's **own** `State`. Every 48 px crossed =
      ±5, clamped 0–9999.
- [ ] Commit each crossing to the parent via `onQtySet`; keep the per-frame translate
      and background local. This is the performance crux — the parent holds 28 rows,
      and a parent `setState` per frame would rebuild all of them. It must fire about
      once per 5 units, not once per frame.
- [ ] Reveal behind the row: green `+5` on right-drag, red `−5` on left-drag.
      **Not `Dismissible`** — that widget's whole purpose is removing rows.
- [ ] Vertical `ListView` scrolling and horizontal row drag do not conflict in
      Flutter's gesture arena; no custom arena work should be needed. If it turns out
      otherwise, that is a finding worth writing down rather than working around.
- [ ] Unpriced products (currently `opacity 0.45` with null callbacks) reject the
      swipe with `HapticFeedback.heavyImpact()` and **no movement** — the rejection
      has to be felt, not just absent.

### Long-press repeat

- [ ] `_StepperBtn` gains `onLongPress` → `Timer.periodic(150ms)` repeating ±5 until
      release. Cancel the timer in `dispose` — a leaked periodic timer here will
      keep mutating quantities after the row is gone.

### Haptics pass

- [ ] `selectionClick` on each 5-crossing, from both swipe and long-press repeat.
- [ ] `mediumImpact` on Confirm Order.
- [ ] `heavyImpact` on rejected input.
- [ ] `lightImpact` on ±1 already exists — leave it.
- [ ] Principle: haptics replace confirmation toasts for reversible actions. Do not
      add a snackbar for anything that now has a haptic.

### Visual weight

- [ ] Zero-quantity rows render at reduced visual weight; non-zero rows get a filled
      quantity chip. No reordering — the list stays alphabetical and stable, because a
      list that reorders under your thumb while you are entering an order is worse
      than a long one.

### Tests

- [ ] `test/dao_test.dart` or a new widget test — the quantity clamp specifically:
      swiping left at 0 does not go negative; swiping right past 9999 clamps; a drag
      of 3 × 48 px produces exactly +15, not +14 or +16 from accumulated rounding.

## Success criteria

- [ ] Entering a realistic 6-product order takes **6 swipes and zero keyboard**.
- [ ] Drag stays at 60 fps on a mid-range Android with all 28 products loaded — profile
      it, do not eyeball it.
- [ ] Swiping left at quantity 0 does nothing and never goes negative.
- [ ] A 3-crossing drag lands on exactly +15.
- [ ] Long-press repeat stops immediately on release and leaves no timer running after
      navigating away.
- [ ] Swiping an unpriced row produces a heavy haptic and zero movement.
- [ ] Both existing input paths still work: ±1 steppers, and tap-the-number → keyboard.
- [ ] Confirm Order is reachable and correct with a mix of swipe-entered and
      keyboard-entered quantities.
