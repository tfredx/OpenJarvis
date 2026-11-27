# Validation gates

| Gate | Evidence |
| --- | --- |
| G0 | Exact source archive hash and provenance |
| G1 | swift test logs and counts |
| G2 | cargo test --locked with resolved lockfile and pinned upstream |
| G3 | ARM64 device and simulator cross-compilation, exported symbol checks |
| G4 | XCFramework creation and unsigned Xcode device/simulator builds |
| G5 | Signed physical iPhone test, model availability, permissions and failure paths |
| G6 | Upstream runtime integration and regression tests |
| G7 | Valid `ios-vX.Y.Z` tag passes complete mobile CI and publishes checksummed unsigned IPA artifact |

A gate is pass only with actual successful evidence on the relevant environment. Owner-reported Mac results (2026-11-27): 55 Swift core tests, simulator and physical-device compilation, and unsigned IPA packaging succeeded; the exact tested commit and logs were not supplied. Owner-reported physical-device execution then passed four basic prompts and failed one no-tool/context prompt plus six targeted semantic-memory prompts. This is partial G5 evidence; required memory, permissions, offline, cancellation/checkpoint, erase and failure-path results are not complete. G3/G4 compilation alone does not establish device execution. Record failures and blocked gates explicitly.
