# Mobile roadmap

| Milestone | Exit condition | Status |
| --- | --- | --- |
| v0.2.1 | Governance merged; baseline imported; CI configured and observable | Complete |
| v0.3.0 | Native Rust bridge compiles/links; security and sessions scoped after validation | CI complete; physical-device runtime gate still open |
| v0.3.1 | Isolated session storage, task-safe native UI, migration and device tests | Partial: isolated sessions and hosted tests pass; on-device persistence and migration still unverified |
| v0.4.0 | Versioned SQLite migration and retrieval tests | Partial: SQLite archive foundation is tested; live migration and retrieval are not wired |
| v0.4.1 | Shadow migration rehearsal preserves source bytes; interruption recovery is journaled and fails closed | Complete in CI; JSON remains authoritative, no live cutover |
| v0.5.0 | Original upstream agent orchestration integrated through a narrow adapter and tested | Next |
| v0.6.0 | Native device tools, scoped permissions and approvals | Not started |
| v0.7.0 | Checkpointed background workflows, measured device limits | Not started |
| v0.8.0 | Additional local models and compute routing | Not started |
| v0.9.0 | Learning and optional Mac companion | Not started |
| v1.0.0 | Release criteria met on physical devices | Not started; physical-device install/runtime validation is open |

## Validation and release packaging

Owner-reported local Mac evidence (2026-11-27): Xcode 27.2, XcodeGen and Rust configured; 55 Swift core tests passed; simulator and physical-device builds and unsigned IPA packaging succeeded. The tested commit and logs were not supplied, so this is not attributed to a specific integration SHA. Physical-device installation and runtime behavior remain unverified.

The mobile CI pipeline already requires portable regression tests, pinned Rust bridge tests/cross-build, hosted native simulator tests, and unsigned arm64 compilation for both `iphoneos` and `iphonesimulator`. The release-artifact increment adds the existing repository security audit as a required dependency and permits release-versioned unsigned IPA artifacts only for valid `ios-vX.Y.Z` tags pointing into `ios/main`; artifact publication follows all jobs passing. The versioned release artifact is unsigned, retained for 90 days, and requires developer signing before installation. Ordinary validated runs also produce short-lived development IPAs. Tagging creates no signed, App Store or production release.

Milestone status is based on CI and explicitly labeled owner-reported evidence. Never equate compilation with device installation or runtime validation. Record future gates and failures in PRs and issues.
