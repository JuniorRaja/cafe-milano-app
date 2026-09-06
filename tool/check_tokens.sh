#!/usr/bin/env bash
#
# The token ratchet.
#
# Counts the design-system violations still left in the app: ad-hoc greys,
# `fontSize:` literals and raw corner radii. Every one of them is a value that
# should come from `lib/theme/tokens.dart`.
#
# The audit counted *distinct values*: 111 ad-hoc greys, 14 distinct font
# sizes, 8 distinct radii. This script counts *sites*, which is the number that
# has to reach zero.
#
# `fontSize:` matches a *literal* only — a digit must follow. A computed size
# is not a hardcoded value and never was what the audit counted; the app has
# exactly one, `letter_avatar.dart`, whose glyph scales with its circle. Starting sites, measured when 10a shipped:
#
#     Colors.grey            139
#     fontSize: literals     198
#     BorderRadius.circular   59
#     ---
#     total                  396
#
# **The count reached zero in 10c and this script is now BLOCKING.** It was a
# reporting step for two releases while 10a shipped the kit and 10c migrated
# the screens; 396 sites became 0. A new literal in `lib/screens/` or
# `lib/widgets/` now fails CI, which is the whole point — tokens that only
# half the app uses are worse than no tokens, because the next person cannot
# tell which half is correct.
#
# What it *does* gate, from day one, is the kit itself: nothing in
# `lib/widgets/ui/` may define a colour, a size or a radius of its own. A kit
# that leaks literals is not a design system.
#

set -uo pipefail
cd "$(dirname "$0")/.."

SCREENS_BLOCKING=1

PATTERNS=(
  'Colors\.grey'
  'fontSize:[[:space:]]*[0-9]'
  'BorderRadius\.circular\('
)
NAMES=(
  'Colors.grey'
  'fontSize: literal'
  'BorderRadius.circular('
)

count_in() {
  # $1 = pattern, rest = paths
  local pattern="$1"; shift
  grep -rn --include='*.dart' -E "$pattern" "$@" 2>/dev/null | wc -l | tr -d ' '
}

# --- The kit: blocking ------------------------------------------------------

kit_failed=0
echo "lib/widgets/ui/ (blocking)"
for i in "${!PATTERNS[@]}"; do
  n=$(count_in "${PATTERNS[$i]}" lib/widgets/ui)
  printf '  %-24s %s\n' "${NAMES[$i]}" "$n"
  if [ "$n" -ne 0 ]; then
    kit_failed=1
    grep -rn --include='*.dart' -E "${PATTERNS[$i]}" lib/widgets/ui | sed 's/^/    /'
  fi
done

# --- Screens and non-kit widgets: reporting until 10c -----------------------

echo
echo "lib/screens/ + lib/widgets/ (excluding the kit)"
screens_total=0
for i in "${!PATTERNS[@]}"; do
  n=$(grep -rn --include='*.dart' -E "${PATTERNS[$i]}" lib/screens lib/widgets 2>/dev/null \
        | grep -v '^lib/widgets/ui/' | wc -l | tr -d ' ')
  printf '  %-24s %s\n' "${NAMES[$i]}" "$n"
  screens_total=$((screens_total + n))
done
echo "  ---"
printf '  %-24s %s\n' 'total remaining' "$screens_total"

if [ "$kit_failed" -ne 0 ]; then
  echo
  echo "FAIL: the component kit must define no values of its own."
  echo "      Use AppColors / AppType / AppRadius from lib/theme/tokens.dart."
  exit 1
fi

if [ "$SCREENS_BLOCKING" -eq 1 ] && [ "$screens_total" -ne 0 ]; then
  echo
  echo "FAIL: $screens_total token violations left in screens."
  exit 1
fi

echo
echo "OK (kit clean; $screens_total token violations)"
