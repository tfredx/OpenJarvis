# Current handoff — portable core import

Date: 2026-11-26 ET. Stage: v0.2.1 source import PR, not a tagged release.

Upstream pin: 556ddf32456bdf5c40195714a3385b339b5f98f9 (open-jarvis/OpenJarvis).
Fork: tfredx/OpenJarvis. Main remains at upstream pin. Governance PR #1 merged into ios/main at f089d88a4d2cc797e08939a8aa7b6eafc6ccfd65.
Current feature branch: feat/ios-import-portable-core. Canonical source path: mobile/ios.
Ruleset Mobile Integration Protection active on ios/main: PR required, deletion and non-fast-forward updates blocked, zero required approvals. Issues enabled. Actions enabled per owner; settings endpoint inaccessible, actual workflow run not yet verified.

## Completed in this increment
- Fresh execution of original v0.2.0 portable Swift package: 16 XCTest tests passed, 0 failures on Linux Swift 6.2.1.
- Package.swift, .gitignore, two source files and two test files transferred into GitHub. Their Git blob hashes match the locally tested archive exactly (see docs/validation/portable-core-import.md).
- Issues #2 (baseline), #3 (CI and native gates), #4 (physical device) created.
- This PR is a partial source import, not a native app or Rust build.

## Next steps
1. Review and merge this portable-core PR into ios/main; no release tag yet.
2. Continue issue #2 from fresh ios/main branch feat/ios-import-native-app. Import original SwiftUI app, Rust bridge, headers, project specs and build scripts from v0.2.0 archive. Verify Git blob hashes of unchanged files; document deliberate path/script changes. Preserve license, historical handoff and QA evidence. Do not replace current governance docs with obsolete archive instructions. Archive SHA-256: 151c029a383a8f94e932e6ac542b803bce6968a1915563c413ed6109276eb650.
3. Issue #3: add mobile-specific CI (read-only permissions, pinned action SHAs, no secrets in PRs). Check Swift package first; add Rust host lockfile and tests, ARM64 targets, unsigned Xcode builds. Verify Xcode 27 runner availability. Do not require checks before observing them.
4. Issue #4: after native link and build gates, install on iPhone and validate real inference, permissions, persistence, restart, cancellation and failure paths.
5. Update handoff, roadmap and validation with every PR. Keep main unchanged.

## Blockers
Local sandbox cannot resolve github.com; no direct archive push. Connector Git tree writes are available. Native app and bridge files not yet imported. Cargo and Apple SDK not present in local test environment. GitHub Actions settings cannot be read via this connector; no CI run claimed. Conversation-resolution requirement is off, nonblocking. No real-device testing, native Rust execution or release tag.
