# Milano Orders

An offline-first Flutter app for running a bakery's daily orders on Android.

Orders are taken against a catalogue of items and customers, sent to a kitchen
view that tracks what still has to be made, and settled through a ledger that
records payments, outstanding balances, and per-customer statements as PDFs.
A dashboard summarises sales, item movement, and receivables over time.

Everything lives in a local SQLite database (drift) on the device — no server,
no account, no network needed. Data moves between devices through JSON backup
files exported and imported from the profile screen.

State is Riverpod; navigation is go_router.
