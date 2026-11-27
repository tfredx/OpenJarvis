#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:---native}"
[[ "$MODE" == --native || "$MODE" == --swift-only ]] || { echo 'Usage: setup-ios.sh [--native|--swift-only]' >&2; exit 1; }
[[ $(uname -s) == Darwin ]] || { echo 'Requires macOS with Xcode 27.' >&2; exit 1; }
xcodebuild -version
sdk=$(xcrun --sdk iphoneos --show-sdk-version)
[[ ${sdk%%.*} -ge 27 ]] || { echo 'Select Xcode 27 or later.' >&2; exit 1; }
command -v xcodegen >/dev/null || { echo 'Install XcodeGen: brew install xcodegen' >&2; exit 1; }
mkdir -p "$ROOT/audit"
(cd "$ROOT" && swift test) 2>&1 | tee "$ROOT/audit/swift-test.log"
if [[ "$MODE" == --native ]]; then
  "$ROOT/scripts/build-rust-bridge.sh"
  SPEC=project-native.yml
else
  SPEC=project.yml
fi
(cd "$ROOT/ios" && xcodegen generate --spec "$SPEC")
for sdk in iphoneos iphonesimulator; do
  if [[ "$sdk" == iphoneos ]]; then DEST="generic/platform=iOS"; else DEST="generic/platform=iOS Simulator"; fi
  xcodebuild -project "$ROOT/ios/OpenJarvisMobile.xcodeproj" -scheme OpenJarvisMobile -sdk "$sdk" -destination "$DEST" ARCHS=arm64 -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath "$ROOT/.ios-build" build 2>&1 | tee "$ROOT/audit/xcode-$sdk.log"
done
open "$ROOT/ios/OpenJarvisMobile.xcodeproj"
