import 'package:flutter/material.dart';

/// Decorative illustration painted behind every shell screen.
///
/// This used to decode `bg-vector.png` at full resolution, run a Gaussian blur
/// through `ImageFiltered`, and composite the result at 50% `Opacity` — with no
/// `RepaintBoundary`. Both `ImageFiltered` and `Opacity` force a `saveLayer`,
/// and this widget sits under *every* shell screen, so it re-ran on every
/// scroll and every animated frame. It was the single largest rendering cost in
/// the app, and it is decorative.
///
/// The blur and the 50% alpha are now baked into `bg-vector-blurred.png`
/// (generated from `bg-vector.png` at sigma 3, alpha halved). Compositing over
/// the opaque cream ground, a halved alpha channel is exactly equivalent to the
/// `Opacity` layer it replaces. No filter, no layer, one `RepaintBoundary`.
///
/// To regenerate after changing the source art, see `tool/blur_background.py`.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Image.asset(
        'bg-vector-blurred.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        // The art is 349px wide and is only ever stretched to cover. Capping
        // the decode keeps the memory cost flat across device pixel ratios.
        cacheWidth: 360,
        filterQuality: FilterQuality.low,
      ),
    );
  }
}
