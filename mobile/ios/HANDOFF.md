# Current handoff — repair security build packaging regression

Date: 2026-11-26 ET. Base ios/main 184e8b459907d409ce164a2cadc1fd36756102d9; upstream pin 556ddf32456bdf5c40195714a3385b339b5f98f9. PR #12 merged; prior PR CI failed. Issue #3 and #4 open. Last fully validated build remains 3b209e9121b64edacfce8cca3f58930af1efccff (run 45932697497, artifact 15169941661).

PR #12 evidence: 21 portable and 10 Rust tests passed; both ARM64 cross-builds passed. Malformed shell code failed before XCFramework; eight hosted tests and new artifact are not validated. See docs/validation/security-packaging-regression.md. Current branch fix/ios-security-packaging repairs the build script and adds portable regression checks. No policy changes. New CI pending.

Next: verify both jobs, actual eight hosted tests and packaging. Merge only after success. Ruleset 28209245 still lacks required checks at inspection; owner must save both check names. Physical device #4 remains open. Defer session feature changes until repaired integrated baseline passes. Do not claim release or full upstream security integration. Keep upstream main intact.