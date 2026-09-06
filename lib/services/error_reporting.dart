import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where a crash goes.
///
/// Local logging only, deliberately. The seam is the point: today an uncaught
/// framework error and a provider that threw both vanish silently, so a defect
/// the owner hits at 5 a.m. leaves no trace by the time it is reported.
/// Doc 10c's error views report through here, and a real crash reporter — if
/// one is ever wanted — replaces the bodies of these three functions and
/// nothing else.
const _tag = '[MilanoOrders]';

void reportError(Object error, StackTrace? stack, {String? context}) {
  final where = context == null ? '' : ' ($context)';
  debugPrint('$_tag error$where: $error');
  if (stack != null) debugPrintStack(stackTrace: stack, label: _tag);
}

/// Installs the two framework-level handlers. Call once, before `runApp`.
void installErrorHandlers() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    reportError(details.exception, details.stack, context: details.library);
    previous?.call(details);
  };

  // Errors that escape the Flutter zone entirely — a platform channel, an
  // unawaited future nobody caught. Returning false lets the process keep its
  // default behaviour on top of the logging.
  PlatformDispatcher.instance.onError = (error, stack) {
    reportError(error, stack, context: 'platform');
    return false;
  };
}

/// Logs every provider that fails to build. A red screen tells you a widget
/// broke; this tells you which provider broke first, which is usually the
/// actual question.
class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    reportError(error, stackTrace, context: provider.name ?? provider.runtimeType.toString());
  }
}
