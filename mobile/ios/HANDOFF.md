# Current handoff — repository foundation

Date: 2026-11-26. Stage: v0.2.1 governance proposal; not a mobile build release.

Upstream: open-jarvis/OpenJarvis; pin: 556ddf32456bdf5c40195714a3385b339b5f98f9.
Fork: tfredx/OpenJarvis. Parent relationship and write access verified. main was at the pinned commit.
Integration branch: ios/main (initialized at upstream pin). This proposal: chore/ios-repository-foundation.
Canonical source path: mobile/ios.

## Existing prototype
v0.2.0 exists as an external source archive, not yet committed here. Archive SHA-256: 151c029a383a8f94e932e6ac542b803bce6968a1915563c413ed6109276eb650.
Prior release reported 16/16 Swift tests passed using Linux Swift 6.2.1. These are historical results, not fresh CI results. Rust bridge source and three authored Rust tests are uncompiled; Xcode and device gates pending.
The current connector can write Git objects but cannot transfer the local archive directly or administer rulesets. Local sandbox cannot reach GitHub over git. No source import or CI execution is claimed.

## Next steps
1. Owner reviews this PR; enable Issues and Actions if desired (fork Issues were disabled), then protect ios/main using available rulesets. Do not require a nonexistent status check.
2. After merge, import the verified v0.2.0 source into mobile/ios on feat/ios-import-v0.2.0; preserve this governance documentation and original license; put historical handoff under docs/handoffs/v0.2.0. Update stale branch/path references.
3. Execute swift test from mobile/ios; capture logs. Open a PR targeting ios/main; review the entire diff.
4. Add CI in a separate PR: portable Swift, Rust host and Apple cross-target checks, then unsigned Xcode builds. Verify hosted Xcode 27 availability; fail explicitly if unavailable. Pin third-party action SHAs, minimize token permissions and avoid secrets on PRs.
5. Only after native build and link gates, test on physical iPhone. Then plan upstream agent migration.

## Acceptance state
- Fork identity/access: verified.
- Branches: initialized; protection not configured.
- Governance: proposed.
- Source import, CI, Rust host, ARM64 iOS, Xcode, device: pending.
- No release tag.
