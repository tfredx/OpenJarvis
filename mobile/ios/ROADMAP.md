# Mobile roadmap

| Milestone | Exit condition | Status |
| --- | --- | --- |
| v0.2.1 | Governance merged; baseline imported; CI configured and observable | Complete |
| v0.3.0 | Native Rust bridge compiles/links; security and sessions scoped after validation | CI complete; memory retrieval and request-level context policy implemented; physical retest pending |
| v0.3.1 | Isolated session storage, task-safe native UI, migration and device tests | Partial: isolated sessions and hosted tests pass; on-device persistence and migration remain unverified |
| v0.4.0 | Versioned SQLite migration and retrieval tests | Partial: archive, shadow migration and transactional SQLite session operations are implemented; JSON remains authoritative and app/backend cutover is not wired |
| v0.4.1 | Shadow migration rehearsal preserves source bytes; interruption recovery is journaled and fails closed | Complete in CI; JSON remains authoritative, no live cutover |
| CI/CD | Versioned unsigned IPA artifacts and validation-gated CI | Complete and integrated in PR #20; release-tag path not yet exercised |
| v0.5.0 | Original upstream agent orchestration integrated through an approval-preserving adapter and tested | Blocked on a consequential Swift/Rust orchestration boundary decision |
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

PR #24 run 46086033077 passed the 66-test portable Swift suite, all security jobs, 10 Rust bridge tests, both unsigned builds and 11 hosted native integration tests, and uploaded development IPA artifact 15239452414. Its native job was ultimately cancelled at final diagnostics-artifact retention; a rerun is queued, so the required job is not green and the PR must not merge yet. SQLite CRUD remains isolated from production JSON persistence. A Python SQLite simulation passed 189 session-position compaction cases; Mac CI must provide the Swift and Apple-platform validation.

Only a valid `ios-vX.Y.Z` tag pointing into `ios/main` enters the versioned release-artifact path. Tag-derived versioning and 90-day artifact retention are implemented but not exercised because no release tag was requested or created. Tagging does not create a signed, App Store or production release. Ordinary CI artifacts remain short-lived. Never equate compilation or simulator tests with device execution.

## v0.5 integration constraint

At the pinned source revision, upstream `openjarvis-agents` uses `rig-core::CompletionModel`; `NativeReActAgent` calls `ToolExecutor` directly, and `OrchestratorAgent` does not yet dispatch tools. The app's inference provider is asynchronous Apple Foundation Models in Swift. The Rust `rig-core` dependency graph includes `reqwest`, which ADR-0002 intentionally excludes from the mobile bridge. Select an integration boundary before changing runtime architecture. Any agent integration must retain explicit user approval, default-deny capabilities, local inference and the current signed-device validation gate.
