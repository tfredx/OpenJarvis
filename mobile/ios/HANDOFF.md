# Current handoff — upstream capability policy proposal

Date: 2026-11-26 ET. Base ios/main 3b209e9121b64edacfce8cca3f58930af1efccff. Upstream 556ddf32456bdf5c40195714a3385b339b5f98f9. PRs #1, #5–#11 merged. Baseline run 45932697497 passed 16 Swift, 3 Rust and 6 hosted tests, both unsigned Xcode builds, archive hashes and artifact publication (15169941661). Issue #4 physical validation open. Required checks were still absent from ruleset 28209245 when inspected.

Current branch feat/ios-capability-policy: direct compilation of unchanged upstream capability module in existing Rust bridge, fixed default-deny grants, independent Swift authorization, approval recheck, implicit memory read gating, additional tests. See docs/decisions/0003-capability-boundary.md. No new capability exposed. No new CI pass claimed. No tag.

Next: verify CI checks and all tests on this head. Review lockfile root dependency edge and upstream blob verification, ensure all original tests pass and native tests exercise the actual policy. Merge only when green and owner has validated the physical baseline per issue #4 (or explicitly accepts deferral). Enable both required checks; close #3 after rule verification and remaining toolchain/dependency review. Then plan sessions, scanner integration and SQLite independently. Preserve upstream main. No credentials or user data in this public repository.
