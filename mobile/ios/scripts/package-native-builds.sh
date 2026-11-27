#!/usr/bin/env bash
# Package separate unsigned app bundles and a development IPA. Release-versioned
# IPA output is reserved for validated ios-vX.Y.Z tags and requires local signing.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ $(uname -s) == Darwin ]] || { echo 'Requires macOS and Xcode.' >&2; exit 1; }
OUT="$ROOT/.ios-build/packages"
mkdir -p "$OUT"
DEVICE_APP=""
for kind in device simulator; do
  if [[ "$kind" == device ]]; then platform=iphoneos; else platform=iphonesimulator; fi
  APP="$ROOT/.ios-build/$kind/Build/Products/Debug-$platform/OpenJarvisMobile.app"
  [[ -d "$APP" && -f "$APP/Info.plist" ]] || { echo "Missing built app: $APP" >&2; exit 1; }
  EXE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")
  IDENTIFIER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
  [[ "$IDENTIFIER" == org.openjarvis.mobileprototype.app && "$EXE" == OpenJarvisMobile ]]
  [[ -f "$APP/$EXE" ]]
  if [[ "$kind" == device ]]; then DEVICE_APP="$APP"; fi
  xcrun lipo -verify_arch arm64 "$APP/$EXE"
  xcrun vtool -show-build "$APP/$EXE" > "$OUT/$kind-build-version.txt"
  if [[ "$kind" == device ]]; then
    grep -Eq 'platform[[:space:]]+IOS[[:space:]]*$' "$OUT/$kind-build-version.txt"
  else
    grep -Eq 'platform[[:space:]]+IOSSIMULATOR[[:space:]]*$' "$OUT/$kind-build-version.txt"
  fi
  ZIP="$OUT/OpenJarvisMobile-$kind-unsigned.zip"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  unzip -tq "$ZIP"
done
APP_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEVICE_APP/Info.plist")
RELEASE_VERSION="${IOS_RELEASE_VERSION:-}"
if [[ -n "$RELEASE_VERSION" ]]; then
  [[ "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid release version: $RELEASE_VERSION" >&2; exit 1; }
  [[ "$APP_VERSION" == "$RELEASE_VERSION" ]] || {
    echo "Built app version $APP_VERSION does not match release $RELEASE_VERSION" >&2
    exit 1
  }
  IPA="$OUT/OpenJarvisMobile-ios-v$RELEASE_VERSION-unsigned.ipa"
else
  IPA="$OUT/OpenJarvisMobile-$APP_VERSION-dev-${GITHUB_RUN_NUMBER:-local}-unsigned.ipa"
fi
rm -f "$IPA"
PAYLOAD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/openjarvis-ipa-payload.XXXXXX")
trap 'rm -rf "$PAYLOAD_ROOT"' EXIT
mkdir -p "$PAYLOAD_ROOT/Payload"
ditto "$DEVICE_APP" "$PAYLOAD_ROOT/Payload/OpenJarvisMobile.app"
ditto -c -k --sequesterRsrc --keepParent "$PAYLOAD_ROOT/Payload" "$IPA"
unzip -tq "$IPA"
unzip -Z1 "$IPA" | grep -qx 'Payload/OpenJarvisMobile.app/Info.plist'
if unzip -Z1 "$IPA" | grep -Eq '^Payload/OpenJarvisMobile\.app/(embedded\.mobileprovision|_CodeSignature/)'; then
  echo 'Refusing to label a provisioning profile or code-signed app as unsigned.' >&2
  exit 1
fi
python3 - <<'PY'
import hashlib, json, os, pathlib, subprocess
out = pathlib.Path(".ios-build/packages")
def command(*args):
    return subprocess.check_output(args, text=True).strip()
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
files = [out / f"OpenJarvisMobile-{kind}-unsigned.zip" for kind in ("device", "simulator")]
release_version = os.environ.get("IOS_RELEASE_VERSION") or None
device_version = os.environ.get("IOS_RELEASE_VERSION") or os.environ.get("IOS_PROJECT_VERSION")
if not device_version:
    device_version = subprocess.check_output([
        "/usr/libexec/PlistBuddy", "-c", "Print :CFBundleShortVersionString",
        ".ios-build/device/Build/Products/Debug-iphoneos/OpenJarvisMobile.app/Info.plist",
    ], text=True).strip()
if release_version:
    files.append(out / f"OpenJarvisMobile-ios-v{release_version}-unsigned.ipa")
else:
    files.append(out / f"OpenJarvisMobile-{device_version}-dev-{os.environ.get('GITHUB_RUN_NUMBER', 'local')}-unsigned.ipa")
manifest = {
    "schema_version": 1,
    "source_commit": command("git", "rev-parse", "HEAD"),
    "github_run_id": os.environ.get("GITHUB_RUN_ID"),
    "xcode": command("xcodebuild", "-version"),
    "cargo_lock_sha256": digest(pathlib.Path("bridge/Cargo.lock")),
    "release_version": release_version,
    "app_version": device_version,
    "distribution": "versioned unsigned IPA; developer signing is required before installation" if release_version else "unsigned development app bundles and IPA",
    "device_compiled": True,
    "simulator_compiled": True,
    "physical_device_tested": False,
    "files": [{"name": p.name, "bytes": p.stat().st_size, "sha256": digest(p)} for p in files],
}
(out / "BUILD-MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")
(out / "SHA256SUMS.txt").write_text("".join(f"{digest(p)}  {p.name}\n" for p in [*files, out / "BUILD-MANIFEST.json"]))
PY
(cd "$OUT" && shasum -a 256 -c SHA256SUMS.txt)
printf 'Verified unsigned bundles and manifest: %s\n' "$OUT"
