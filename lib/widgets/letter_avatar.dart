import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class LetterAvatar extends StatelessWidget {
  const LetterAvatar({super.key, required this.name, this.radius = 24});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.brandDeep,
      child: Text(
        letter,
        // The one size in the app that is not a token, and cannot be: the
        // glyph scales with the circle it sits in, so it is a computed value
        // rather than one of the eight steps. Family, weight and colour still
        // come from the system.
        style: AppType.titleM.copyWith(
          color: AppColors.textOnDark,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}
