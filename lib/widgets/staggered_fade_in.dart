import 'package:flutter/material.dart';

/// Fades a list in **once**, as a whole.
///
/// Two versions of this were wrong before, in opposite ways.
///
/// The original staggered each row by `30ms * index` on top of a 250 ms fade,
/// so the last visible row of an 18-shop list appeared 360 ms after the data
/// was ready. Doc 10a cut that to a single 150 ms fade.
///
/// What 10a left in place was worse for scrolling, and is what the owner felt
/// as stutter. The widget was applied **inside `itemBuilder`**, and
/// `itemBuilder` runs every time a row scrolls into view — so each new row
/// started its own `TweenAnimationBuilder`, and every frame of it composited
/// through an `Opacity`, which forces a `saveLayer`. Scrolling a long list
/// meant a continuous supply of fresh animated layers, one per row, forever.
///
/// So this now wraps the **list**, not the row. One animation, one layer, and
/// it is finished 150 ms after the list first appears no matter how far the
/// user scrolls.
///
/// Applying it per row is the bug; [ListFadeIn] takes a whole list for exactly
/// that reason.
class ListFadeIn extends StatelessWidget {
  const ListFadeIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}
