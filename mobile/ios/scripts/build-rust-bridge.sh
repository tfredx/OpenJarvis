#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ $(uname -s) == Darwin ]] || { echo 'Requires macOS, Xcode, and rustup.' >&2; exit 1; }
command -v rustup >/dev/null && command -v cargo >/dev/null || { echo 'Install Rust via rustup.' >&2; exit 1; }
xcrun --sdk iphoneos --show-sdk-version
xcrun --sdk iphonesimulator --show-sdk-version
mkdir -p "$ROOT/audit" "$ROOT/ios/Frameworks"
cd "$ROOT/bridge"
# Pin the compiler that passed host tests and both Apple cross-builds.
TOOLCHAIN=1.100.0
rustup toolchain install "$TOOLCHAIN" --profile minimal --component llvm-tools-preview
rustup target add --toolchain "$TOOLCHAIN" aarch64-apple-ios aarch64-apple-ios-sim
rustc +"$TOOLCHAIN" -vV | tee "$ROOT/audit/rustc-version.txt"
cargo +"$TOOLCHAIN" --version | tee "$ROOT/audit/cargo-version.txt"
HOST=$(rustc +"$TOOLCHAIN" -vV | sed -n 's/^host: //p')
SYSROOT=$(rustc +"$TOOLCHAIN" --print sysroot)
NM="$SYSROOT/lib/rustlib/$HOST/bin/llvm-nm"
[[ -n "$HOST" && -x "$NM" ]] || { echo "Matching Rust llvm-nm not found: $NM" >&2; exit 1; }
"$NM" --version | tee "$ROOT/audit/llvm-nm-version.txt"
export CARGO_TARGET_DIR="$ROOT/bridge/target"
# Lockfile is checked in; missing or changed dependency resolution is a hard failure.
[[ -f Cargo.lock ]] || { echo "Missing bridge/Cargo.lock; restore reviewed lockfile." >&2; exit 1; }
cargo +"$TOOLCHAIN" test --locked 2>&1 | tee "$ROOT/audit/bridge-host-test.log"
export IPHONEOS_DEPLOYMENT_TARGET=27.0
for target in aarch64-apple-ios aarch64-apple-ios-sim; do
  cargo +"$TOOLCHAIN" build --release --locked --target "$target" 2>&1 | tee "$ROOT/audit/bridge-$target.log"
done
for target in aarch64-apple-ios aarch64-apple-ios-sim; do
  # Xcode 27.1 nm cannot read LLVM 23 Rust archive metadata; use the producer's reader.
  # This does not replace the later Apple linker validation.
  "$NM" --extern-only --defined-only --no-demangle "$CARGO_TARGET_DIR/$target/release/libopenjarvis_mobile_bridge.a" > "$ROOT/audit/symbols-$target.txt" 2> "$ROOT/audit/symbols-$target.stderr.log"
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
