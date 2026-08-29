import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dev_seed.dart';
import 'database_provider.dart';

/// Everything that has to happen once before the app is usable.
///
/// This used to run above `runApp` in `main()`, which had two consequences.
/// A throw during seeding meant `runApp` was never reached at all, so the user
/// sat looking at a native splash that would never resolve — no error, no
/// retry, nothing to report. And the work blocked the first frame even when it
/// succeeded.
///
/// Now `runApp` goes first and this runs underneath a live widget tree, so a
/// failure has somewhere to be displayed. `AppBootstrapGate` watches it.
class Bootstrap extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    final db = ref.watch(databaseProvider);

    // A trivial round trip is the only honest "the database is open" signal:
    // the provider hands back an AppDatabase before the file has been opened,
    // so constructing it proves nothing.
    await db.customSelect('SELECT 1').get();

    if (kDebugMode) {
      await seedFromBackup(db);
    }
  }
}

final bootstrapProvider = AsyncNotifierProvider<Bootstrap, void>(Bootstrap.new);
