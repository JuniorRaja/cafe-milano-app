import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/bootstrap_provider.dart';
import '../ui/ui.dart';

/// Holds the native splash up until the app can actually be used, and takes it
/// down exactly once — either onto the first real frame or onto an error
/// screen.
///
/// `main()` used to call `FlutterNativeSplash.remove()` on the line after
/// `runApp`, which runs before the first frame is rasterised: the native splash
/// came down onto nothing and the user saw a blank flash. Removal now waits for
/// a post-frame callback on a frame that contains the real UI.
class AppBootstrapGate extends ConsumerStatefulWidget {
  const AppBootstrapGate({super.key, required this.child});

  /// The routed app. Null only in the frame or two before the router has
  /// produced anything, which `MaterialApp.router`'s builder allows for.
  final Widget? child;

  @override
  ConsumerState<AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends ConsumerState<AppBootstrapGate> {
  bool _splashRemoved = false;

  void _removeSplashAfterFrame() {
    if (_splashRemoved) return;
    _splashRemoved = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(bootstrapProvider);
    final child = widget.child ?? const SizedBox.shrink();

    return bootstrap.when(
      // Still opening the database. The native splash is on top of this, so
      // the child builds behind it and is ready the moment it comes down.
      loading: () => child,

      data: (_) {
        _removeSplashAfterFrame();
        return child;
      },

      // The splash has to come down here too, or the error screen is drawn
      // underneath it and the user gets the held splash all over again.
      error: (error, stack) {
        _removeSplashAfterFrame();
        return _BootstrapErrorScreen(
          error: error,
          onRetry: () => ref.invalidate(bootstrapProvider),
        );
      },
    );
  }
}

class _BootstrapErrorScreen extends StatelessWidget {
  const _BootstrapErrorScreen({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Its own Directionality and Material: this sits outside the Navigator, so
    // it cannot assume any of MaterialApp's inherited widgets are above it.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: AppColors.bg,
        child: AppErrorView(
          message: 'The app could not start.',
          cause: '$error',
          onRetry: onRetry,
        ),
      ),
    );
  }
}
