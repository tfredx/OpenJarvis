# Mobile roadmap

| Milestone | Exit condition | Status |
| --- | --- | --- |
| v0.2.1 | Governance merged; baseline imported; CI configured and observable | Complete |
| v0.3.0 | Native Rust bridge compiles/links; security and sessions scoped after validation | Integrated; memory retrieval/request policy implemented; PR #26 diagnostics code integrated, validation evidence not yet verified |
| v0.3.1 | Isolated session storage, task-safe native UI, migration and device tests | Partial: isolated sessions and hosted tests passed historically; on-device persistence remains unverified |
| v0.4.0 | Versioned SQLite migration and retrieval tests | Partial: PR #25 transactional SQLite operations integrated; JSON remains authoritative; PR #25 integrated CI status is unknown here; production cutover is not wired |
| v0.4.1 | Shadow migration preserves source bytes; recovery journal fails closed | Implemented and previously CI-validated; production cutover remains disabled pending full migration and signed-device protection gates |
| CI/CD | Required regression/security/device+simulator compile validation and versioned downloadable unsigned release artifacts | Pipeline integrated and validated on prior PRs; release-tag path not exercised |
| v0.5.0 | Swift-first upstream contracts with local inference, bounded execution and explicit approvals | Adapter merged in PR #27; integrated CI unverified; concrete upstream Rust agent is not linked |
| v0.6.0 | Scoped native device providers with platform permission and approval tests | PR #28 capability dispatcher integrated at `6206921f`. Scoped Calendar reader implemented on `feat/ios-scoped-calendar-reader`; unregistered with no OS permission request. CI and device tests pending. |
| v0.7.0 | Checkpointed background workflows with measured device limits | Not started |
| v0.8.0 | Additional local models and compute routing based on benchmark evidence | Not started; Foundation Models remains default |
| v0.9.0 | Inspectable personalization and separately reviewed optional Mac companion | Not started |
| v1.0.0 | Release matrix passes, including critical physical-device workflows | Not started; physical-device execution is partial, with unresolved memory/context failures |

## Validation evidence

Owner-reported Mac work (2026-11-27): Xcode 27.2, XcodeGen and Rust configured; 55 Swift core tests passed; simulator and physical-device compilation and unsigned IPA packaging succeeded. The commit/logs were not supplied, so this does not map to a validated repository SHA.

Owner-reported physical iPhone execution: four basic prompts passed; a process explanation with explicit tool/memory denial failed; six semantic retrieval prompts failed. Device/OS/build identifiers and logs were not supplied. PR #26's eight-scenario diagnostic runner is integrated at `8277355`; current-build physical retest remains pending. No performance or reliable-inference claim is established.

Historical CI evidence is retained: PR #20/#21 integrated CI passed; PR #22 PR/integrated runs passed all seven jobs, including 62 Swift, 10 Rust bridge, 11 hosted integration tests, security checks, arm64 iPhoneOS and simulator builds, packaging and artifact upload (15237619676). PR #23 PR/integrated runs passed all seven jobs and uploaded artifact 15238954029. PR #24 ran 66 Swift tests, 10 Rust, 11 hosted integration tests and native/security checks and uploaded artifact 15239452414, but its final native job was cancelled during diagnostics retention; it is not a successful required conclusion. PR #25 merged the SQLite session operations; its integrated CI result is unknown based on the status tools available here. PR #26 is merged, but the examined workflow/status endpoints exposed no checks for merge commit `8277355`; do not report green CI without direct run evidence.

The versioned IPA workflow produces unsigned artifacts. The release-tag path and 90-day retention have not been exercised. Unsigned IPA packaging and device-target compilation do not establish signed installation or physical-device behavior.

## Integration and dependency rules

PR #26 diagnostics and PR #27 Swift-first adapter are integrated. PR #28 is refreshed against `84944000710a716af3862adedd7e5ba91bd15a7b`. Preserve scope and require complete passing required checks before merging.

Keep SQLite JSON-to-database production cutover disabled until the foundation's integrated CI is verified and migration interruption, readback, rollback-after-write, backup exclusion, sidecar file protection and signed-device data protection pass. Never restore an outdated JSON source after SQLite writes without preserving later data.

## v0.5 agent boundary

ADR-0009 accepts a Swift adapter using pinned upstream agent contract shapes while keeping Apple Foundation Models as the native inference provider. At the pinned upstream revision, Rust `NativeReActAgent` dispatches through `ToolExecutor`, and `OrchestratorAgent` does not yet perform tool dispatch; directly linking it would also bring `rig-core`/`reqwest` and would need a separate approval-safe execution boundary. The Swift adapter is an adaptation, not reuse of the concrete Rust runtime. Continue with deterministic mocked providers, a state machine, bounded planning/actions, explicit approvals, cancellation and recovery tests.

## Next executable work

1. Verify PR #27 integrated CI and PR #28 refreshed-head CI without repeatedly polling queued runners.
2. Add deterministic scripted intelligence-provider tests and explicit failure classification to the diagnostics/orchestration path.
3. Implement migration-state/recovery fault injection only after verified SQLite foundation CI; keep production cutover disabled until signed-device protections are established.
4. Implement one native provider at a time, beginning with read-only Calendar, after scoped permission and approval review.
5. Continue checkpointed workflows, routing and personalization only with deterministic regression evidence and honest platform limits.

Never equate compilation or simulator execution with physical-device testing. Preserve historical failures and actual test counts; do not fabricate performance measurements.


## PR #29 — comparative diagnostics

Runs identical synthetic inputs through direct Apple generation and the production agent entry point. Report schema 2 adds elapsed time and content-free failure codes. Prevents concurrent live tasks during diagnostics and documents a consolidated signed-device batch.

Depends on integrated PRs #26 and #27. No new permissions, dependencies, network access or persistence changes. Scripted tests cover independent failure evidence and report redaction. Local whitespace and build-script checks passed. Swift, native builds and device tests were unavailable locally. Require full CI before merge. Session creation and hardware behavior remain unverified.

Current branch refreshed against PR #31 integration; required CI pending.


## PR #33 — task activity

Shows the latest task using real conversation and checkpoint data. Adds expandable outcomes and existing approval, cancellation and recovery operations to the Activity tab. Documents the supported execution path and deferred background options. Independent of #29–#32. Local whitespace and build-script fixtures passed. Swift/Xcode CI, Dynamic Type and VoiceOver validation remain pending. No additional permissions or storage schema changes.

Refreshed after PR #29 integration; required CI pending.
