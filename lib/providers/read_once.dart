import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The provider convention, and the one helper it needs.
///
/// **Everything keyed on an argument is `autoDispose`.** Before this release 0
/// of 35 providers used it, so every distinct argument to
/// `orderSummariesForDateProvider(date)`, `shopLedgerProvider(...)` and friends
/// created an instance that lived for the process lifetime holding an open
/// Drift stream. Stepping back fourteen days on the home screen left fourteen
/// live subscriptions re-running on every write — the cause that got worse the
/// longer a session ran.
///
/// Deliberately **not** `autoDispose`: `databaseProvider`,
/// `selectedDateProvider`, `dashboardSettingsProvider`, `brandProvider`, and
/// the unparameterised master lists (`activeShopsProvider`,
/// `allProductsProvider`, `outstandingByShopProvider`, …). Those are genuinely
/// app-lifetime.
extension ReadOnce on WidgetRef {
  /// One-shot read of an `autoDispose` stream provider — for an export or a
  /// share, where the screen wants the value now and never again.
  ///
  /// A bare `ref.read(p.future)` is a trap on an `autoDispose` provider: `read`
  /// registers no listener, so the provider is disposed on the next tick and
  /// the future never completes. Holding a manual subscription across the await
  /// is what keeps it alive.
  Future<T> readStreamOnce<T>(AutoDisposeStreamProvider<T> provider) async {
    final sub = listenManual(provider, (_, _) {});
    try {
      return await read(provider.future);
    } finally {
      sub.close();
    }
  }

  /// [readStreamOnce] for an `autoDispose` future provider.
  Future<T> readFutureOnce<T>(AutoDisposeFutureProvider<T> provider) async {
    final sub = listenManual(provider, (_, _) {});
    try {
      return await read(provider.future);
    } finally {
      sub.close();
    }
  }
}
