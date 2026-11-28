#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p audit
xcrun simctl list devices available -j > audit/simulator-devices.json
DEVICE=$(python3 - <<'PY'
import json, re, sys
d = json.load(open("audit/simulator-devices.json"))
candidates = []
for runtime, devices in d["devices"].items():
    m = re.search(r"\.iOS-(\d+)(?:-(\d+))?", runtime)
    if not m or int(m[1]) < 27:
        continue
    for device in devices:
        if device.get("isAvailable", True) and device["name"].startswith("iPhone"):
            candidates.append((int(m[1]), int(m[2] or 0), device["name"] == "iPhone 17 Pro", device["name"], device["udid"]))
if not candidates:
    sys.exit("No available iOS 27+ iPhone simulator; runtime validation cannot proceed.")
print(max(candidates)[-1])
PY
)
printf '%s\n' "$DEVICE" | tee audit/simulator-udid.txt
RESULT="$ROOT/audit/native-integration.xcresult"
DERIVED="$ROOT/.ios-build/simulator"
[[ ! -e "$RESULT" ]] || { echo "Existing result bundle: remove or archive it before running again." >&2; exit 1; }
# Refuse stale test configurations before building. Use the exact configuration
# emitted by this invocation to run tests and package the same simulator host.
shopt -s nullglob
existing=("$DERIVED"/Build/Products/*.xctestrun)
[[ ${#existing[@]} -eq 0 ]] || { echo "Existing simulator test configuration: use fresh simulator derived data." >&2; exit 1; }

build_args=(-project ios/OpenJarvisMobile.xcodeproj -scheme OpenJarvisMobile
  -sdk iphonesimulator -destination "platform=iOS Simulator,id=$DEVICE"
  -configuration Debug ARCHS=arm64 CODE_SIGNING_ALLOWED=NO
  -derivedDataPath "$DERIVED")
if [[ -n "${IOS_RELEASE_VERSION:-}" ]]; then
  : "${IOS_RELEASE_BUILD:?A release build number is required}"
  build_args+=("MARKETING_VERSION=$IOS_RELEASE_VERSION" "CURRENT_PROJECT_VERSION=$IOS_RELEASE_BUILD")
fi
xcodebuild "${build_args[@]}" build-for-testing 2>&1 | tee audit/xcode-simulator.log
configurations=("$DERIVED"/Build/Products/*.xctestrun)
[[ ${#configurations[@]} -eq 1 && -f "${configurations[0]}" ]] || {
  echo "Expected exactly one simulator test configuration from this build." >&2; exit 1;
}
xcodebuild -xctestrun "${configurations[0]}" -destination "platform=iOS Simulator,id=$DEVICE" \
  -parallel-testing-enabled NO -resultBundlePath "$RESULT" \
  test-without-building 2>&1 | tee audit/native-integration.log
grep -Eq 'Executed [1-9][0-9]* tests?, with 0 failures' audit/native-integration.log
grep -Fq '** TEST SUCCEEDED **' audit/native-integration.log
