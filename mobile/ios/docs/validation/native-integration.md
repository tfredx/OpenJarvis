# Native integration validation — first compiled build and runtime test proposal

Baseline: d8b47c2a0e4d0815af6100f01176671718e41d1e, upstream pin 556ddf32456bdf5c40195714a3385b339b5f98f9.

PR #9 run 45931605877 (head 569e1e14f99a501de35552910754e6a3fbb77bbb):
- Portable job 140285309257: Swift 6.4.2; 16 tests, 0 failures.
- Native job 140285547357: Xcode 27.1 (27A9275), XcodeGen 2.48.0, matching LLVM 23.1.5, Rust 1.100.0; 3 Rust tests passed, both ARM64 targets built, symbol gate passed, XCFramework written, both unsigned Xcode builds succeeded.
- Cargo.lock SHA-256 4006df18f100df468fde3be16c0c197e540b75895afa8567bf50bfaa9023e992 unchanged. See https://github.com/tfredx/OpenJarvis/actions/runs/45931605877.
- This is compilation and linking evidence, not application runtime or actual inference.

This PR adds six hosted XCTest methods to the native-only Xcode project and an explicit test scheme. The CI script selects an available iOS 27+ iPhone simulator dynamically (preferring 17 Pro within the newest runtime), runs xcodebuild test with a dedicated result bundle, requires actual nonzero test execution and success, and retains logs and xcresult in existing audit artifacts. It does not skip if no simulator exists.

Tests exercise the actual compiled Rust bridge (not fallback): selection, all window sizes and Unicode including embedded NUL in JSON, invalid bounds and oversized history, repeated allocations/empty responses, approval persistence across agent recreation and repeated denial. Model responses are deterministic; no model or network is needed. No physical iPhone data. Actual hosted test execution is pending; scheme, signing and simulator boot errors may need follow-up. XcodeGen version observed but not pinned yet.

Next: inspect CI on this PR, fix any failures, and merge only after portable and native gates pass. Require both check names on ios/main once verified. Then add device installation instructions and execute physical validation (#4). No release until hardware evidence.
