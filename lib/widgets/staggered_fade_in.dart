import 'package:flutter/material.dart';

/// Fades a list in. **No longer staggers** — the name and the file stay so the
/// diff at the ~6 call sites is legible; doc 10c renames them.
///
/// The old version gave each row `30ms * index` (capped at 12) plus a 250 ms
/// fade, so the last visible row of an 18-shop list appeared **360 ms after the
/// data was ready** and the list animated for ~600 ms. Each row was also its
/// own `StatefulWidget` with its own `Future.delayed` and `setState`.
///
/// One 150 ms fade, one implicit animation, no timers, no per-row state.
/// [index] is ignored and kept only so call sites need not change.
class StaggeredFadeIn extends StatelessWidget {
  const StaggeredFadeIn({super.key, this.index = 0, required this.child});

  /// Ignored. Retained so the existing call sites compile unchanged.
  final int index;

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
