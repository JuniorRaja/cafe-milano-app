import 'package:clock/clock.dart';

/// `Good morning`, `Good afternoon` or `Good evening`.
///
/// This existed before and was deleted in commit `ddd08d8`, for a good reason
/// badly applied. The greeting was fine; what went with it was
/// `const _greetingNames = ['Mohan', 'JMR']` picked by `Random()` at library
/// load — a business identity hardcoded in a widget file, which AGENTS.md rule
/// 6 forbids, and fixed for the process anyway because the seed ran once.
/// Deleting the line took the greeting with it. This is the greeting on its
/// own, with no name in it.
///
/// The boundaries are the ones the deleted version used: morning from 05:00,
/// afternoon from 12:00, evening from 17:00 through the small hours.
///
/// Reads the wall clock through `package:clock` (AGENTS.md rule 14), so the
/// boundaries are tested by moving a clock rather than by waiting until five.
/// Pass [at] to ask about a specific moment.
String greetingFor([DateTime? at]) {
  final hour = (at ?? clock.now()).hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// The greeting with whoever the app is greeting, for a screen header.
///
/// [businessName] is `BusinessInfo.name` — the only name this app stores, and
/// the name of a *business* rather than a person. Blank or unset, the greeting
/// stands alone rather than addressing the owner by their shopfront.
String greetingLine({String? businessName, DateTime? at}) {
  final greeting = greetingFor(at);
  final name = businessName?.trim() ?? '';
  return name.isEmpty ? greeting : '$greeting, $name';
}
