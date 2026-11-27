#!/usr/bin/env bash
# Package the separately built, unsigned app bundles; never produce an installable IPA.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ $(uname -s) == Darwin ]] || { echo 'Requires macOS and Xcode.' >&2; exit 1; }
OUT="$ROOT/.ios-build/packages"
mkdir -p "$OUT"
for kind in device simulator; do
  if [[ "$kind" == device ]]; then platform=iphoneos; else platform=iphonesimulator; fi
  APP="$ROOT/.ios-build/$kind/Build/Products/Debug-$platform/OpenJarvisMobile.app"
  [[ -d "$APP" && -f "$APP/Info.plist" ]] || { echo "Missing built app: $APP" >&2; exit 1; }
  EXE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")
  IDENTIFIER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
  [[ "$IDENTIFIER" == org.openjarvis.mobileprototype.app && "$EXE" == OpenJarvisMobile ]]
  [[ -f "$APP/$EXE" ]]
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
python3 - <<'PY'
import hashlib, json, os, pathlib, subprocess
out = pathlib.Path(".ios-build/packages")
def command(*args):
    return subprocess.check_output(args, text=True).strip()
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
files = [out / f"OpenJarvisMobile-{kind}-unsigned.zip" for kind in ("device", "simulator")]
manifest = {
    "schema_version": 1,
    "source_commit": command("git", "rev-parse", "HEAD"),
    "github_run_id": os.environ.get("GITHUB_RUN_ID"),
    "xcode": command("xcodebuild", "-version"),
    "cargo_lock_sha256": digest(pathlib.Path("bridge/Cargo.lock")),
    "distribution": "unsigned development build; not an installable IPA",
    "device_validated": False,
    "files": [{"name": p.name, "bytes": p.stat().st_size, "sha256": digest(p)} for p in files],
}
(out / "BUILD-MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")
(out / "SHA256SUMS.txt").write_text("".join(f"{digest(p)}  {p.name}\n" for p in [*files, out / "BUILD-MANIFEST.json"]))
PY
(cd "$OUT" && shasum -a 256 -c SHA256SUMS.txt)
printf 'Verified unsigned bundles and manifest: %s\n' "$OUT"
