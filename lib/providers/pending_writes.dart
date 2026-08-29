import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/error_reporting.dart';

/// Writes that are debounced in a screen and have not reached the database
/// yet.
///
/// Order entry batches a save 500 ms behind the last keystroke. Leaving the
/// screen already flushes it (doc 18), but backgrounding the app did not:
/// Android can suspend or kill the process from `paused` without ever calling
/// `dispose`, so the last quantity typed before the phone went in a pocket was
/// lost. This is the seam `AppLifecycleScope` flushes through.
///
/// Kept deliberately small — a set of callbacks, no ordering, no results. A
/// screen registers on the way in and unregisters on the way out.
class PendingWrites {
  final _flushers = <Future<void> Function()>{};

  /// Returns the unregister callback. Call it from `dispose`.
  VoidCallback register(Future<void> Function() flush) {
    _flushers.add(flush);
    return () => _flushers.remove(flush);
  }

  int get pendingCount => _flushers.length;

  /// Runs every registered flush. Failures are logged, never thrown: this runs
  /// while the app is being suspended and there is nobody left to show an
  /// error to.
  Future<void> flushAll() async {
    for (final flush in _flushers.toList()) {
      try {
        await flush();
      } catch (e, s) {
        reportError(e, s, context: 'pending write flush');
      }
    }
  }
}

final pendingWritesProvider = Provider<PendingWrites>((ref) => PendingWrites());
