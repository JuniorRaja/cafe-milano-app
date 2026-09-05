import 'package:clock/clock.dart';

/// `Good morning`, `Good afternoon` or `Good evening`.
///
/// This existed before and was deleted in commit `ddd08d8`, for a good reason
/// badly applied. The greeting was fine; what went with it was
/// `const _greetingNames = ['Mohan', 'JMR']` picked by `Random()` at library
/// load — a business identity hardcoded in a widget file, which AGENTS.md rule
/// 6 forbids, and fixed for the process anyway because the seed ran once.
/// Deleting the line took the greeting with it.
///
/// **This is the greeting and nothing else.** It carried a name once, and the
/// owner's call on 2026-09-05 was to leave it off: the only name the app stores
/// is `BusinessInfo.name`, which names a shopfront rather than a person, and
/// there is nowhere to keep a person's name without a schema change the roadmap
/// froze at v6.
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
