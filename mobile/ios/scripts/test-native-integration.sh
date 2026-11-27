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
# xcodebuild boots the selected simulator and executes hosted XCTest.
# Keep the separate unsigned device and simulator build gates in CI.
RESULT="$ROOT/audit/native-integration.xcresult"
[[ ! -e "$RESULT" ]] || { echo "Existing result bundle: remove or archive it before running again." >&2; exit 1; }
xcodebuild -project ios/OpenJarvisMobile.xcodeproj -scheme OpenJarvisMobile \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -configuration Debug -parallel-testing-enabled NO \
  -derivedDataPath .ios-build/native-test \
  -resultBundlePath "$RESULT" \
  test 2>&1 | tee audit/native-integration.log
grep -Eq 'Executed [1-9][0-9]* tests?, with 0 failures' audit/native-integration.log
grep -Fq '** TEST SUCCEEDED **' audit/native-integration.log
