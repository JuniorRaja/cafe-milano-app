import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Collapses several `AsyncValue`s into one, so a screen can `.when` once.
///
/// This exists to kill `maybeWhen(orElse:)`. That spelling gave **error** the
/// same fallback as **loading** — usually an empty list — so a failed query
/// rendered as "nothing here". On the Kitchen screen that meant a database
/// failure was drawn as *"No orders for this date"*, telling the operator
/// there was nothing to bake. See `docs/flutter-lifecycle-audit.md` Phase 3.
///
/// **Error wins over loading.** If one query has already failed, a sibling
/// still in flight does not make the screen healthy — reporting `loading`
/// there would spin forever on a screen that is never going to load.
///
/// [build] is called only when every part has data, so it may use
/// `requireValue` freely.
AsyncValue<T> combineAsync<T>(
  List<AsyncValue<Object?>> parts,
  T Function() build,
) {
  for (final part in parts) {
    if (part case AsyncError(:final error, :final stackTrace)) {
      return AsyncError<T>(error, stackTrace);
    }
  }
  if (parts.any((part) => part.isLoading)) return AsyncLoading<T>();
  return AsyncData<T>(build());
}
