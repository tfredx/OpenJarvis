# Current handoff — v0.4.1 complete; v0.5 next

Date: 2026-11-27 ET. Integration base `ios/main` is `079f4220e6d204c55672701b247034eb82ad10ad`; upstream pin remains `556ddf32456bdf5c40195714a3385b339b5f98f9`. PR #18 and #19 are merged. Their final CI runs passed; integrated run 45945261330 passed both jobs, including 55 portable Swift tests, 10 Rust bridge host tests, 11 hosted native simulator tests, ARM64 device and simulator builds, packaging and artifact publication.

## Owner-reported Mac validation

On 2026-11-27, Tim reported configuring an Apple silicon Mac with Xcode 27.2, XcodeGen and Rust, passing all 55 Swift core tests, compiling the simulator and physical-device targets, and packaging an unsigned IPA. The exact tested commit and local logs were not supplied in this handoff, so keep this evidence marked owner-reported and do not attribute it to a specific commit without confirmation. Physical-device installation, pairing and runtime testing remain pending; no on-device feature or performance result is claimed.

## Current increment — versioned release artifacts

Branch `feat/ios-ipa-releases` adds `ios-vX.Y.Z` tag validation and a versioned unsigned IPA artifact after the portable regression suite, the existing reusable security audit, the pinned Rust bridge tests/cross-build, simulator integration tests, and both arm64 app builds succeed. Release tags must point to a commit contained in `ios/main`. The artifact is a GitHub Actions artifact with 90-day retention, not a signed/public store release; the IPA requires developer signing before installation. The release workflow and docs still require validation by CI before merge.

Local checks on this branch: `git diff --check` passed; `bash mobile/ios/scripts/test-build-scripts.sh` passed, including accepted version/ancestry and rejected tag/foreign-commit fixtures. This workspace has no Swift or Xcode toolchain, so do not claim local Swift, Xcode, or actual IPA packaging results for this branch. Its macOS PR job packages a development IPA on every validated run; the tag-specific version injection and publication remain to be confirmed by a future validated tag run.

No runtime permission, dependency, live storage cutover or source deletion is included. SQLite rehearsal and recovery remain disconnected from app startup; JSON remains authoritative. Do not modify upstream `main`, commit signing material, or claim physical-device execution.

## Next

After the release-artifact increment passes PR and integrated CI, begin v0.5: integrate original OpenJarvis agent orchestration against the pinned upstream source, keeping the Swift approval boundary, Rust capability policy and local inference constraints intact. First map upstream agent APIs and dependencies against the current Agent, then select a narrow adapter with regression tests. Avoid enabling broad upstream tools or network access. Continue to treat actual device installation/runtime validation as an open release gate, not a blocker to code development.
