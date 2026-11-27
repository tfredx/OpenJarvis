#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM="${1:-$ROOT/upstream/OpenJarvis}"
[[ $(uname -s) == Darwin ]] || { echo 'Run on macOS with Xcode and Rust.' >&2; exit 1; }
command -v cargo >/dev/null && command -v rustup >/dev/null || { echo 'Install Rust with rustup first.' >&2; exit 1; }
if [[ ! -d "$UPSTREAM/.git" ]]; then mkdir -p "$(dirname "$UPSTREAM")"; git clone https://github.com/open-jarvis/OpenJarvis.git "$UPSTREAM"; git -C "$UPSTREAM" checkout --detach 556ddf32456bdf5c40195714a3385b339b5f98f9; fi
mkdir -p "$ROOT/audit"
cd "$UPSTREAM/rust"
[[ $(git rev-parse HEAD) == 556ddf32456bdf5c40195714a3385b339b5f98f9 ]] || { echo "Check out pinned upstream commit 556ddf32456bdf5c40195714a3385b339b5f98f9 first." >&2; exit 1; }
git rev-parse HEAD > "$ROOT/audit/upstream-commit.txt"
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
cargo metadata --format-version 1 --no-deps > "$ROOT/audit/workspace.json"
python3 - "$ROOT/audit/workspace.json" <<'PY' > "$ROOT/audit/packages.txt"
import json,sys
wanted={'openjarvis-core','openjarvis-agents','openjarvis-engine','openjarvis-tools','openjarvis-learning','openjarvis-sessions','openjarvis-traces','openjarvis-security','openjarvis-workflow','openjarvis-skills'}
for p in json.load(open(sys.argv[1]))['packages']:
    if p['name'] in wanted: print(p['name'])
PY
printf 'package\ttarget\tstatus\n' > "$ROOT/audit/results.tsv"
while IFS= read -r crate; do
  for target in aarch64-apple-ios aarch64-apple-ios-sim; do
    if cargo check --locked -p "$crate" --target "$target" > "$ROOT/audit/$crate-$target.log" 2>&1; then result=PASS; else result=FAIL; fi
    printf '%s\t%s\t%s\n' "$crate" "$target" "$result" | tee -a "$ROOT/audit/results.tsv"
  done
done < "$ROOT/audit/packages.txt"
cat "$ROOT/audit/results.tsv"
if [[ ! -s "$ROOT/audit/packages.txt" ]] || grep -q $'\tFAIL' "$ROOT/audit/results.tsv"; then exit 1; fi
