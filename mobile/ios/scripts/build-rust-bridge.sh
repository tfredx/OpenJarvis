#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ $(uname -s) == Darwin ]] || { echo 'Requires macOS, Xcode, and rustup.' >&2; exit 1; }
command -v rustup >/dev/null && command -v cargo >/dev/null || { echo 'Install Rust via rustup.' >&2; exit 1; }
xcrun --sdk iphoneos --show-sdk-version
xcrun --sdk iphonesimulator --show-sdk-version
mkdir -p "$ROOT/audit" "$ROOT/ios/Frameworks"
cd "$ROOT/bridge"
# Use the same toolchain as upstream (minimum Rust 1.89); stable may be newer.
rustup target add --toolchain stable aarch64-apple-ios aarch64-apple-ios-sim
export CARGO_TARGET_DIR="$ROOT/bridge/target"
# Cargo.lock is generated on the first run. Retain it in the fork for later reproducibility.
if [[ ! -f Cargo.lock ]]; then cargo +stable generate-lockfile; fi
cargo +stable test --locked 2>&1 | tee "$ROOT/audit/bridge-host-test.log"
export IPHONEOS_DEPLOYMENT_TARGET=27.0
for target in aarch64-apple-ios aarch64-apple-ios-sim; do
  cargo +stable build --release --locked --target "$target" 2>&1 | tee "$ROOT/audit/bridge-$target.log"
done
for target in aarch64-apple-ios aarch64-apple-ios-sim; do
  xcrun nm -gU "$CARGO_TARGET_DIR/$target/release/libopenjarvis_mobile_bridge.a" > "$ROOT/audit/symbols-$target.txt"
  grep -Eq '[[:space:]]_oj_window_json$' "$ROOT/audit/symbols-$target.txt"
  grep -Eq '[[:space:]]_oj_string_free$' "$ROOT/audit/symbols-$target.txt"
done
OUTPUT="$ROOT/ios/Frameworks/OpenJarvisBridge.xcframework"
TEMP=$(mktemp -d)
trap 'rm -rf "$TEMP"' EXIT
xcodebuild -create-xcframework \
 -library "$CARGO_TARGET_DIR/aarch64-apple-ios/release/libopenjarvis_mobile_bridge.a" -headers "$ROOT/bridge/include" \
 -library "$CARGO_TARGET_DIR/aarch64-apple-ios-sim/release/libopenjarvis_mobile_bridge.a" -headers "$ROOT/bridge/include" \
 -output "$TEMP/OpenJarvisBridge.xcframework" 2>&1 | tee "$ROOT/audit/xcframework.log"
rm -rf "$OUTPUT"
mv "$TEMP/OpenJarvisBridge.xcframework" "$OUTPUT"
printf 'Built %s; app linking/device test still required.\n' "$OUTPUT"
