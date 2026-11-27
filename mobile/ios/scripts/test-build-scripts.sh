#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for script in "$ROOT"/scripts/*.sh; do bash -n "$script"; done
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
VERIFY="$ROOT/scripts/verify-bridge-symbols.sh"
printf 'archive-member.o:\n0000000000000000 T _oj_window_json\n0000000000000020 T _oj_string_free\n0000000000000040 T _oj_authorize_action_json\n' > "$TMP/valid"
"$VERIFY" "$TMP/valid"
for symbol in _oj_window_json _oj_string_free _oj_authorize_action_json; do
  awk -v symbol="$symbol" '$NF != symbol' "$TMP/valid" > "$TMP/missing"
  if "$VERIFY" "$TMP/missing"; then echo "Accepted missing $symbol" >&2; exit 1; fi
  awk -v symbol="$symbol" '$NF == symbol {$NF = symbol "_lookalike"} {print}' "$TMP/valid" > "$TMP/lookalike"
  if "$VERIFY" "$TMP/lookalike"; then echo "Accepted lookalike $symbol" >&2; exit 1; fi
  awk -v symbol="$symbol" '$NF == symbol {$(NF-1) = "U"} {print}' "$TMP/valid" > "$TMP/undefined"
  if "$VERIFY" "$TMP/undefined"; then echo "Accepted undefined $symbol" >&2; exit 1; fi
done
if "$VERIFY" "$TMP/absent"; then echo 'Accepted absent file' >&2; exit 1; fi
: > "$TMP/empty"
if "$VERIFY" "$TMP/empty"; then echo 'Accepted empty file' >&2; exit 1; fi
# Syntax alone did not detect the prior malformed quoted block.
# Check the build script has a single packaging phase and calls the verifier.
BUILD="$ROOT/scripts/build-rust-bridge.sh"
[[ $(grep -c '^TEMP=$(mktemp -d)$' "$BUILD") -eq 1 ]]
[[ $(grep -c '^xcodebuild -create-xcframework' "$BUILD") -eq 1 ]]
[[ $(grep -c 'scripts/verify-bridge-symbols.sh' "$BUILD") -eq 1 ]]
TAG_VALIDATOR="$ROOT/scripts/validate-ios-release-tag.sh"
MAIN_REPO="$TMP/release-main"
OTHER_REPO="$TMP/release-other"
git init -q "$MAIN_REPO"
git -C "$MAIN_REPO" config user.name 'OpenJarvis CI Test'
git -C "$MAIN_REPO" config user.email 'ci-test@example.invalid'
printf 'base\n' > "$MAIN_REPO/source"
git -C "$MAIN_REPO" add source
git -C "$MAIN_REPO" commit -qm 'base'
BASE_SHA=$(git -C "$MAIN_REPO" rev-parse HEAD)
printf 'main\n' > "$MAIN_REPO/source"
git -C "$MAIN_REPO" commit -qam 'ios main'
MAIN_SHA=$(git -C "$MAIN_REPO" rev-parse HEAD)
VERSION=$("$TAG_VALIDATOR" ios-v1.2.3 "$BASE_SHA" "$MAIN_SHA" "$MAIN_REPO")
[[ "$VERSION" == 1.2.3 ]]
if "$TAG_VALIDATOR" ios-v1.2.3-rc.1 "$BASE_SHA" "$MAIN_SHA" "$MAIN_REPO"; then
  echo 'Accepted a non-release iOS version tag' >&2
  exit 1
fi
git init -q "$OTHER_REPO"
git -C "$OTHER_REPO" config user.name 'OpenJarvis CI Test'
git -C "$OTHER_REPO" config user.email 'ci-test@example.invalid'
printf 'unrelated\n' > "$OTHER_REPO/source"
git -C "$OTHER_REPO" add source
git -C "$OTHER_REPO" commit -qm 'unrelated'
OTHER_SHA=$(git -C "$OTHER_REPO" rev-parse HEAD)
git -C "$MAIN_REPO" fetch -q "$OTHER_REPO" "$OTHER_SHA"
if "$TAG_VALIDATOR" ios-v1.2.3 "$OTHER_SHA" "$MAIN_SHA" "$MAIN_REPO"; then
  echo 'Accepted a release commit outside ios/main history' >&2
  exit 1
fi
printf 'PASS: shell syntax, symbol fixtures, release-tag guard and packaging structure checks\n'
