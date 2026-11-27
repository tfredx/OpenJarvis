# Current handoff — integrated CI validation

Date: 2026-11-26 ET. Stage: v0.2.1, full baseline merged; CI hardening proposal. No release tag.
Fork tfredx/OpenJarvis; upstream pin 556ddf32456bdf5c40195714a3385b339b5f98f9. Base ios/main 79cbe01830842ad96297285f91c92d9a13507edc; main unchanged. Governance #1, portable import #5, native import #6 and CI bootstrap #7 merged. Issue #2 completed; #3 and #4 open.

## Evidence
- Integrated CI run [45931139897](https://github.com/tfredx/OpenJarvis/actions/runs/45931139897): portable job 140283783381 passed all 16 XCTest tests on Swift 6.4.3 (0 failures); native job 140283989915 running when last checked. Earlier portable-only CI runs succeeded; native skipped before baseline merge.
- Original native source and portable hashes: docs/validation/native-source-import.md and docs/validation/portable-core-import.md. Native application still unvalidated until actual compiler and device evidence.
- Current feature branch chore/ios-ci-hardening removes transitional native skip and retains diagnostic artifacts/lockfile; no new source behavior or runtime validation claimed. See docs/handoffs/ci-validation-hardening.md.

## Next steps
1. Inspect integrated run and this PR's jobs/logs; address first failing native gate in a scoped PR, without disabling required native validation. Check exact Xcode/Rust versions. Do not merge failing PRs.
2. Download resolved Cargo.lock from diagnostics artifact once generated; verify provenance, review dependency graph, commit lockfile and pin exact Rust and XcodeGen versions. Make bridge script require lockfile. Record toolchain and CI results. If artifact download is inaccessible, use GitHub Actions UI or owner download.
3. Validate Rust host tests, arm64 iOS device/simulator cross-builds, symbols, XCFramework and unsigned Xcode builds; add native interoperability tests. Configure required checks only after they exist and are verified. Issue #3 remains open.
4. Issue #4: signed physical iPhone validation with real Apple Foundation Models inference, permission behavior, approvals, persistence, cancellation/restart and Siri/Shortcuts prefill. Do not treat unsigned compilation as device success.
5. After native gates, scope upstream security/session work. Maintain AGENTS.md and handoff on every PR. Keep main as upstream mirror.

## Limitations
No native build outcome yet. No simulator runtime or physical-device evidence. Lockfile absent from repository. CI artifact upload not yet executed. No secrets or user data in public repo.
