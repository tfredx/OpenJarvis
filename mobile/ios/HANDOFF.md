# Current handoff — native build distribution

Date: 2026-11-26 ET. Stage: v0.2.2 simulator validation pending, packaging proposal. No release tag.
Fork tfredx/OpenJarvis; upstream pin 556ddf32456bdf5c40195714a3385b339b5f98f9; ios/main base 17965e4b7f8121bcd57ff1570d1d4b55c4592810. PRs #1, #5–#10 merged. Issue #2 closed; #3 and #4 open. Current branch build/ios-native-artifacts.

## Evidence
PR #9 run 45931605877 passed 16 portable tests, 3 Rust host tests, both ARM64 cross-builds, symbols, XCFramework and unsigned Xcode device/simulator builds. PR #10 runs 45932108318 and 45932210379 passed portable jobs; native jobs still in progress when checked. No hosted simulator test pass yet. Branch rules currently require PR but not status checks.

## Current change
Add verified unsigned device and simulator ZIP artifacts after native hosted tests, build manifest/checksums and device-installation guide. No runtime changes. No new test results or packaged artifacts claimed until CI completes. See docs/validation/native-artifacts.md.

## Next steps
1. Inspect actual native jobs for PR #10 and this branch; if any hosted tests fail, fix first concrete error in scoped PR. Require both CI jobs and observed six hosted tests before merge.
2. Confirm unsigned artifact archive/manifest upload and checksum; do not represent as signed installable IPA.
3. Owner enables required status checks Mobile portable Swift tests and Mobile native iOS build on ios/main; verify ruleset. Pin XcodeGen and audit dependencies. Issue #3 remains open.
4. Follow docs/DEVICE_INSTALL.md and issue #4 on Mac/iPhone; record actual synthetic device validation. Do not expand runtime until validated.
5. Then scope upstream security/session management. Keep main untouched; each PR updates this handoff.
