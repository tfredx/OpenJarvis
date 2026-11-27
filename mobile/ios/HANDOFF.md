# Current handoff — native toolchain compatibility

Date: 2026-11-26 ET. Stage: v0.2.1 integrated native CI; no release tag.
Fork tfredx/OpenJarvis; upstream pin 556ddf32456bdf5c40195714a3385b339b5f98f9. Base ios/main b17f0b330e654667d6bf818d082ee159276ef627; main unchanged. PRs #1, #5, #6, #7, #8 merged. Issue #2 closed; #3 and #4 open.
Current branch fix/ios-rust-symbol-verification.

## Evidence
- Run 45931139897 passed 16 portable Swift tests, 3 Rust host tests and both ARM64 Rust release cross-builds. Xcode 27.1 initialized. The native job was cancelled after Apple nm reported LLVM metadata incompatibilities. No successful symbol, XCFramework or app link gate.
- PR #8 diagnostics retention merged; its portable job and artifact upload passed. Native runs 45931291104 and 45931375008 still in progress when checked.
- See docs/validation/native-toolchain-compatibility.md for exact failure, evidence and proposed fix.

## Next actions
1. Review this branch's CI and prior native jobs. Do not merge until portable and native checks succeed. If nm succeeds but Apple linking fails, diagnose that separately rather than skipping the gate.
2. Recover Cargo.lock from native artifact; verify against artifact/run provenance, review and commit it, require --locked without regeneration, pin XcodeGen. Record actual toolchain versions.
3. Confirm both Xcode unsigned builds, add real simulator integration tests and require observed CI checks in ios/main ruleset. Issue #3 remains open.
4. Physical iPhone signed deployment and real Apple Foundation Models test (issue #4): permissions, approvals, persistence, restart, cancellation, unavailable model, Shortcut prefill.
5. Only after native validation proceed with upstream security/session migration. Keep source and docs scoped; no secrets or personal data.

Limitations: This fix is not yet CI-tested; Cargo.lock and native link/device results not yet available. No feature expansion or release.
