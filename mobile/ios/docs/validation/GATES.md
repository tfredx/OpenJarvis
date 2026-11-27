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

A gate is pass only with actual successful evidence on the relevant environment. Historical prototype Swift results do not establish current repository CI. Record failures and blocked gates explicitly.
