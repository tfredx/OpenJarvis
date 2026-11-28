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
| v0.6.0 | Scoped native device providers with platform permission and approval tests | PR #28 capability dispatcher integrated at `6206921f`. Scoped Calendar reader integrated in #31. Registration and permission request remain gated. |
| v0.7.0 | Checkpointed background workflows with measured device limits | Not started |
| v0.8.0 | Additional local models and compute routing based on benchmark evidence | Not started; Foundation Models remains default |
| v0.9.0 | Inspectable personalization and separately reviewed optional Mac companion | Not started |
| v1.0.0 | Release matrix passes, including critical physical-device workflows | Not started; physical-device execution is partial, with unresolved memory/context failures |

## Validation evidence

Owner-reported Mac work (2026-11-27): Xcode 27.2, XcodeGen and Rust configured; 55 Swift core tests passed; simulator and physical-device compilation and unsigned IPA packaging succeeded. The commit/logs were not supplied, so this does not map to a validated repository SHA.

Owner-reported physical iPhone execution: four basic prompts passed; a process explanation with explicit tool/memory denial failed; six semantic retrieval prompts failed. Device/OS/build identifiers and logs were not supplied. PR #26's eight-scenario diagnostic runner is integrated at `8277355`; PR #29 added direct-versus-agent comparison. Current-build physical retest remains pending. No performance or reliable-inference claim is established.

Historical CI evidence is retained: PR #20/#21 integrated CI passed; PR #22 PR/integrated runs passed all seven jobs, including 62 Swift, 10 Rust bridge, 11 hosted integration tests, security checks, arm64 iPhoneOS and simulator builds, packaging and artifact upload (15237619676). PR #23 PR/integrated runs passed all seven jobs and uploaded artifact 15238954029. PR #24 ran 66 Swift tests, 10 Rust, 11 hosted integration tests and native/security checks and uploaded artifact 15239452414, but its final native job was cancelled during diagnostics retention; it is not a successful required conclusion. PR #25 merged the SQLite session operations; its integrated CI result is unknown based on the status tools available here. PR #26 is merged, but the examined workflow/status endpoints exposed no checks for merge commit `8277355`; do not report green CI without direct run evidence.

The versioned IPA workflow produces unsigned artifacts. The release-tag path and 90-day retention have not been exercised. Unsigned IPA packaging and device-target compilation do not establish signed installation or physical-device behavior.

## Integration and next milestones

PRs #25–#33 are integrated at `76acd8ddb8ae977d501315fe3efd1b5d45ca0ddb`. GitHub has suspended Actions on the fork. Keep required checks intact and reestablish exact-commit validation before publishing an artifact.

1. **Inference.** Run two signed-device diagnostic trials on the same verified build.
2. **Execution.** Build the deterministic Calendar and Reminders briefing and approval-bound creation. Record uncertainty before any external write and require reconciliation after an interruption.
3. **Capabilities.** Enable only user-selected Calendar and Reminder scopes after permission review. Require OS authorization and current app approval.
4. **Persistence.** Define durable task and action checkpoints. Keep JSON authoritative until SQLite migration, rollback, backup and signed-device protection gates pass. Preserve later writes during rollback.
5. **Observability.** Extend latest task activity into durable task history as checkpoints become available.

Keep shared handoff and roadmap updates in dedicated integration documentation commits.
