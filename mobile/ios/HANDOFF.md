# Current handoff — native source import

Date: 2026-11-26 ET. Stage: v0.2.1 baseline import; no release tag.
Upstream pin: 556ddf32456bdf5c40195714a3385b339b5f98f9. Fork: tfredx/OpenJarvis.
Integration branch ios/main protected; governance #1 and portable import #5 merged. Base: 20363d4f37e12834c80f291524efd228d16f71e9. Feature: feat/ios-import-native-app.
Canonical directory: mobile/ios. Main remains upstream mirror.

## Completed
- Original v0.2.0 archive SHA-256 151c029a383a8f94e932e6ac542b803bce6968a1915563c413ed6109276eb650.
- Fresh Swift 6.2.1 Linux regression: 16 XCTest tests, 0 failures. Swift frontend syntax parse of two app files, bash syntax of three scripts, C header syntax all passed. No Apple SDK type-check.
- Native app, Rust bridge, project specs and build scripts staged from archive. See docs/validation/native-source-import.md for exact source provenance.
- Retired standalone fork creation script intentionally omitted; repository already exists. Historical archive remains available separately.

## Next steps
1. Review and merge native import PR into ios/main; issue #2 can close after acceptance review.
2. Issue #3: establish portable CI and then native gates; verify workflow write authorization and hosted Xcode 27 availability. Pin action SHAs, read-only token, no secrets, fail explicitly if unavailable. Retain resolved Cargo.lock and pin Rust toolchain after initial successful resolution.
3. Run Rust host tests, device/simulator cross-build, symbol checks, XCFramework creation, unsigned Xcode builds. Fix failures sequentially. Add native integration tests; do not infer runtime correctness from compilation.
4. Issue #4: sign and run on physical iPhone; verify real on-device inference, memory approvals, persistence, cancellation, restart, model unavailability and Shortcut prefill. Device tests remain owner-assisted.
5. Only then scope upstream security and sessions. Continue with AGENTS.md and update this handoff each PR.

## Blockers / risks
Cargo and Apple SDK unavailable in local Linux environment; no native compilation or actual inference. Swift-only syntax parse cannot check Apple API availability. Cargo.lock not generated. Setup script currently opens Xcode at end (CI should use explicit headless steps or add a no-open mode). No native CI results. JSON persistence and Swift agent orchestration remain as prototype. No signing assets or private data in repo.
