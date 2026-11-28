# Mobile roadmap

| Milestone | Exit condition | Status |
| --- | --- | --- |
| v0.2.1 | Governance merged; baseline imported; CI configured and observable | Complete |
| v0.3.0 | Native Rust bridge compiles/links; security and sessions scoped after validation | CI integrated; memory retrieval and request policy implemented; diagnostics harness in PR #26, CI/device validation pending |
| v0.3.1 | Isolated session storage, task-safe native UI, migration and device tests | Partial: isolated sessions and hosted tests pass; on-device persistence and migration remain unverified |
| v0.4.0 | Versioned SQLite migration and retrieval tests | PR #25 transactional operations integrated at `ede3b22`; integrated CI result unknown in this session; JSON remains authoritative and production cutover is not wired |
| v0.4.1 | Shadow migration rehearsal preserves source bytes; interruption recovery is journaled and fails closed | Complete in CI; JSON remains authoritative, no live cutover |
| CI/CD | Versioned unsigned IPA artifacts and validation-gated CI | Complete and integrated in PR #20; release-tag path not yet exercised |
| v0.5.0 | Swift-first orchestration follows pinned upstream OjAgent/AgentContext/AgentResult contracts with local inference and approvals | Implemented in PR #27; CI pending; Rust `openjarvis-agents` implementation not linked |
| v0.6.0 | Native device tools, scoped permissions and approvals | Not started |
| v0.7.0 | Checkpointed background workflows, measured device limits | Not started |
| v0.8.0 | Additional local models and compute routing | Not started |
| v0.9.0 | Learning and optional Mac companion | Not started |
| v1.0.0 | Release criteria met on physical devices | Not started; physical-device acceptance is partial and includes unresolved memory/context failures |

## Validation and release packaging

Owner-reported local Mac evidence (2026-11-27): Xcode 27.2, XcodeGen and Rust configured; 55 Swift core tests passed; simulator and physical-device compilation and unsigned IPA packaging succeeded. The tested commit/logs were not supplied, so this is not attributed to a specific integration SHA.

Owner-reported physical-device diagnostic execution (2026-11-27): four basic generation prompts passed; “Explain how a seed grows. Do not use tools or memory.” failed; six targeted semantic-memory prompts failed. Exact device/OS, commit and logs/timings were not supplied. See `docs/validation/physical-memory-diagnostics.md`. This is partial physical-device evidence and does not establish performance or complete v1.0 acceptance.

PR #20 added the existing repository security audit as a required CI dependency and validated both arm64 iPhoneOS and simulator compilation, hosted iOS simulator integration tests, IPA packaging and development-artifact upload. PR run 46070616432 and integrated `ios/main` run 46072060277 passed. PR #21 run 46073658513 and integrated run 46074641626 passed all seven jobs. Integrated workflow run 46072060277 uploaded development artifact 15233712034. Its checksummed IPA is unsigned and reports `physical_device_tested: false`; it predates the later owner-reported device execution.

PR #22 initial CI identified and corrected a weak lexical match and a context-window issue; an intermediate CI run also caught a truncated test source transfer, which was restored. PR run 46082211356 passed all seven jobs. Integrated run 46083177104 also passed all seven: 62 portable Swift tests, 10 Rust bridge tests/cross-build, 11 hosted native integration tests, five security audits, unsigned arm64 device/simulator builds and artifact packaging. Integrated development artifact 15237619676 is unsigned and does not attest to physical-device execution.

PR #24's native run 46086033077 executed the 66-test portable suite, security jobs, 10 Rust bridge tests, both unsigned builds and hosted native integration tests, and uploaded artifact 15239452414; the native job ended cancelled at final diagnostics-artifact retention. PR #25 merged the same SQLite operations into `ios/main` as `ede3b22`. Its integrated push-run is not exposed by the current connected status tools, so its validation result is unknown here. The production app still uses JSON; cutover is gated on confirmed CI and physical data-protection evidence. The prior local Python SQLite position-compaction simulation covered 189 cases.

PR #26 adds synthetic inference diagnostics with redacted reporting; no CI or physical result is asserted. PR #27 implements the Swift-first upstream agent contract adapter; test sources are authored but were not run because this environment lacks Swift/Xcode. Both need complete required CI before merge. PR #27 is being updated with the merged base through a normal merge commit, not a force push.

Only a valid `ios-vX.Y.Z` tag pointing into `ios/main` enters the versioned release-artifact path. Tag-derived versioning and 90-day artifact retention are implemented but not exercised because no release tag was requested or created. Tagging does not create a signed, App Store or production release. Ordinary CI artifacts remain short-lived. Never equate compilation or simulator tests with device execution.

## v0.5 integration boundary

At the pinned revision, concrete Rust `openjarvis-agents` uses `rig-core::CompletionModel`; `NativeReActAgent` calls `ToolExecutor` directly, and `OrchestratorAgent` does not yet dispatch tools. ADR-0009 accepts the owner-directed Swift-first adapter using upstream core data/result contracts while retaining Apple Foundation Models. Direct Rust agent linkage remains deferred to avoid `rig-core`/`reqwest` and the unguarded executor. Any future integration must retain explicit approval, default-deny capabilities, local inference and signed-device validation.
