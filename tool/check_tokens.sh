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
# has to reach zero. Starting sites, measured when 10a shipped:
#
#     Colors.grey            139
#     fontSize: literals     198
#     BorderRadius.circular   59
#     ---
#     total                  396
#
# **This script is EXPECTED TO REPORT VIOLATIONS on day one.** 10a ships the
# tokens and the kit; 10c migrates the 20 screens that still carry literals.
# Until then this runs in CI as a reporting step: it prints the counts so the
# number is visible and can only go down.
#
# What it *does* gate, from day one, is the kit itself: nothing in
# `lib/widgets/ui/` may define a colour, a size or a radius of its own. A kit
# that leaks literals is not a design system.
#
# Flip SCREENS_BLOCKING to 1 at the end of 10c.

set -uo pipefail
cd "$(dirname "$0")/.."

SCREENS_BLOCKING=0

PATTERNS=(
  'Colors\.grey'
  'fontSize:'
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
echo "OK (kit clean; $screens_total screen violations remain for 10c)"
