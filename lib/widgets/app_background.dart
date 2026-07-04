import 'dart:ui';

import 'package:flutter/material.dart';

/// Decorative bakery illustration painted behind screen content.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Image.asset(
          'bg-vector.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}
