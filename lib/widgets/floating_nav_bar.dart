import 'dart:async';
import 'package:flutter/material.dart';
import 'shell/destinations.dart';
import 'ui/ui.dart';

/// The floating pill nav bar.
///
/// Five evenly-spaced slots, built from `destinations.dart` rather than a
/// hardcoded tuple array. Adding or reordering a slot is a change to that list
/// and nothing else.
///
/// The centre gap and its FAB are gone as of the 1.11 revision. The FAB opened
/// a three-item quick-action sheet; each of those actions now sits where the
/// user already is — a new order is a tap on a shop in Orders, a payment is the
/// FAB on Finances, a new shop is the FAB on the shop list — so the slot went
/// back to being a destination.
///
/// Labels are shown. With five slots an icon-only bar asks the user to
/// remember which pictogram means Billing and which means Orders, and they are
/// both rectangles with lines on them.
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
  bool _reducedMotion = false;
  bool _scheduled = false;

  static final _slots = bottomBarDestinations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
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
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      height: 62,
      margin: EdgeInsets.fromLTRB(
        AppSpace.s3,
        AppSpace.s2,
        AppSpace.s3,
        AppSpace.s2 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.rFull,
        boxShadow: AppShadow.card,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _slots.length; i++)
            Expanded(child: _Slot(
              destination: _slots[i],
              selected: widget.selectedIndex == i,
              onTap: () => widget.onDestinationSelected(i),
            )),
        ],
      ),
    );

    if (_reducedMotion) return bar;
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(_curved),
        child: bar,
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brandDeep : AppColors.textTertiary;

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.rFull,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: color,
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                style: AppType.caption.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
