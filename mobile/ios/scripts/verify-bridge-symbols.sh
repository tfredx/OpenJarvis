#!/usr/bin/env bash
# Verify all three externally defined C ABI exports in llvm-nm output.
set -euo pipefail
[[ $# -eq 1 && -f "$1" ]] || { echo 'Usage: verify-bridge-symbols.sh <llvm-nm output>' >&2; exit 2; }
for symbol in _oj_window_json _oj_string_free _oj_authorize_action_json; do
  if ! awk -v expected="$symbol" '$NF == expected && $(NF-1) ~ /^[Tt]$/ { found=1 } END { exit !found }' "$1"; then
    echo "Required code symbol missing: $symbol ($1)" >&2
    exit 1
  fi
done
printf 'Verified all three C ABI symbols in %s\n' "$1"
