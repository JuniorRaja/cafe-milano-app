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
  late final CurvedAnimation _curved;
  late final Animation<Offset> _leftIconSlide;
  late final Animation<Offset> _rightIconSlide;
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
    _curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _leftIconSlide =
        Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
            .animate(_curved);
    _rightIconSlide =
        Tween<Offset>(begin: const Offset(-0.3, 0), end: Offset.zero)
            .animate(_curved);
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

    return SlideTransition(
      position: fromLeft ? _leftIconSlide : _rightIconSlide,
      child: FadeTransition(
        opacity: _controller,
        child: ScaleTransition(scale: _curved, child: icon),
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

    final half = _icons.length ~/ 2;
    final leftIcons = [
      for (var i = 0; i < half; i++) _buildIcon(i, fromLeft: true),
    ];
    final rightIcons = [
      for (var i = half; i < _icons.length; i++) _buildIcon(i, fromLeft: false),
    ];

    return Container(
      height: 64,
      margin: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
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
        children: [...leftIcons, fabGap, ...rightIcons],
      ),
    );
  }
}
