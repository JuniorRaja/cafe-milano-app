import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../providers/database_provider.dart';
import '../../theme/brand_config.dart';

/// Shortest possible gap between the native splash and the first interactive
/// frame, so the logo does not flash and vanish on a fast device.
const _minVisible = Duration(milliseconds: 400);

/// Hard cap. If the database has not answered by now, go anyway — the home
/// screen shows its own loading state and is a better place to wait.
const _maxVisible = Duration(milliseconds: 600);

/// The Flutter splash, shown on top of the native one.
///
/// This used to run a fixed 1200 ms `AnimationController` and navigate on
/// `AnimationStatus.completed`: nothing was being waited on, the animation
/// *was* the wait. It now waits on the database actually answering a query,
/// floored at [_minVisible] and capped at [_maxVisible].
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();

  late final Animation<double> _scale = Tween<double>(begin: 0.92, end: 1).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_go());
  }

  Future<void> _go() async {
    // A trivial round trip is the only honest "the database is open" signal:
    // the provider hands back an AppDatabase before the file is opened.
    final ready = ref
        .read(databaseProvider)
        .customSelect('SELECT 1')
        .get()
        .then((_) {})
        .catchError((_) {});

    await Future.wait([
      Future<void>.delayed(_minVisible),
      ready.timeout(_maxVisible, onTimeout: () {}),
    ]);

    if (mounted) context.go(AppRoutes.home);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _controller,
          child: ScaleTransition(
            scale: _scale,
            child: Image.asset(
              brand.logoAsset,
              width: 160,
              height: 160,
              // 284 KB PNG decoded at full resolution to be drawn at 160x160.
              cacheWidth: 320,
            ),
          ),
        ),
      ),
    );
  }
}
