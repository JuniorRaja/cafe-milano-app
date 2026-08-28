import 'dart:async';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Loading placeholder shaped like the content that is coming. Replaces the 12
/// bare `CircularProgressIndicator`s, which told the user nothing about what
/// they were waiting for and made every screen flash a different layout.
///
/// A single pulsing opacity, not a shimmer sweep: one animation for the whole
/// group rather than one per row.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = AppRadius.rS,
  });

  /// A stack of [count] row-shaped skeletons, for a list that is loading.
  static Widget list({int count = 5, EdgeInsetsGeometry? padding}) {
    return ListView.builder(
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpace.s4,
            vertical: AppSpace.s2,
          ),
      itemCount: count,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpace.s2),
        child: AppSkeleton(height: 64, borderRadius: AppRadius.rM),
      ),
    );
  }

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: widget.borderRadius,
          ),
        ),
      ),
    );
  }
}
