import 'package:flutter/material.dart';
import '../app.dart';

/// Icon-only floating pill nav bar with a center gap for the shared FAB.
class FloatingNavBar extends StatefulWidget {
  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reducedMotion = false;
  bool _scheduled = false;

  static const _icons = [
    (outlined: Icons.home_outlined, filled: Icons.home),
    (outlined: Icons.receipt_long_outlined, filled: Icons.receipt_long),
    (outlined: Icons.restaurant_outlined, filled: Icons.restaurant),
    (outlined: Icons.person_outline, filled: Icons.person),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_reducedMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildIcon(int index, {required bool fromLeft}) {
    final entry = _icons[index];
    final selected = widget.selectedIndex == index;

    final icon = IconButton(
      icon: Icon(selected ? entry.filled : entry.outlined),
      color: selected ? kBrandBrown : Colors.grey.shade600,
      onPressed: () => widget.onDestinationSelected(index),
    );

    if (_reducedMotion) return icon;

    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    final slideOffset = fromLeft
        ? Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero).animate(curved)
        : Tween<Offset>(begin: const Offset(-0.3, 0), end: Offset.zero).animate(curved);

    return SlideTransition(
      position: slideOffset,
      child: FadeTransition(
        opacity: _controller,
        child: ScaleTransition(scale: curved, child: icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fabGap = ScaleTransition(
      scale: _reducedMotion
          ? const AlwaysStoppedAnimation(1)
          : CurvedAnimation(
              parent: _controller,
              curve: const Interval(0.3, 1, curve: Curves.easeOutBack),
            ),
      child: const SizedBox(width: 56),
    );

    return Container(
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildIcon(0, fromLeft: true),
          _buildIcon(1, fromLeft: true),
          fabGap,
          _buildIcon(2, fromLeft: false),
          _buildIcon(3, fromLeft: false),
        ],
      ),
    );
  }
}
