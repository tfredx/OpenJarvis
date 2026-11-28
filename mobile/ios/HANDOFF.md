# Current handoff — memory retrieval integrated; SQLite cutover remains open

Date: 2026-11-27 ET. `ios/main` is `3046f73ffaae9d03ecd84f3bca0c8bc60e74cfc0` after PR #22. PR run 46082211356 and integrated run 46083177104 both passed all seven jobs: 62 portable Swift tests, 10 Rust bridge tests/cross-build, 11 hosted native integration tests, five security audit jobs, unsigned arm64 iPhoneOS and simulator builds, and package/artifact upload. Integrated development artifact 15237619676 contains the unsigned install package. Earlier PR #20 run 46070616432/integrated 46072060277 and PR #21 run 46073658513/integrated 46074641626 also passed.

## Owner-reported Mac validation

On 2026-11-27, Tim reported configuring an Apple silicon Mac with Xcode 27.2, XcodeGen and Rust, passing all 55 Swift core tests, compiling simulator and physical-device targets, and packaging an unsigned IPA. The tested commit and local logs were not supplied; keep this evidence owner-reported and unattributed to a specific SHA.

Tim later reported actual OpenJarvis execution on a physical iPhone using synthetic prompts: four basic responses passed, the request “Explain how a seed grows. Do not use tools or memory.” failed, and six targeted semantic-retrieval prompts failed. Device model, OS version, tested commit and logs/timings were not provided. This establishes partial physical-device execution, not complete G5 acceptance, overall feature correctness or performance. See `docs/validation/physical-memory-diagnostics.md`.

## Release artifact pipeline — merged and validated

PR #20 adds the reusable repository security audit as a required native-build dependency, valid `ios-vX.Y.Z` tag validation against `ios/main`, tag-derived app version/build number, unsigned IPA packaging and checksummed artifacts. The validated PR and integrated CI runs uploaded development IPAs. Integrated artifact 15233712034 is available from [workflow run 46072060277](https://github.com/tfredx/OpenJarvis/actions/runs/46072060277); its package contains the device and simulator app bundles, IPA, manifest and checksums. I downloaded the PR artifact from run 46070616432 and verified its ZIP checksums and `Payload/OpenJarvisMobile.app/Info.plist`; the IPA manifest explicitly reports `physical_device_tested: false`.

No `ios-vX.Y.Z` tag has been created, so tag-specific version injection and 90-day release-artifact publication are configured but have not yet run. No signed, App Store or production release was created. Release artifacts require developer signing for installation.

## Current code increment — semantic recall and request policy

PR #22 adds on-device Apple sentence-embedding ranking with lexical fallback for approved memories, and enforces request-level denials before context assembly and action dispatch. Denied tasks exclude stored notes and prior-task history while retaining allowed current-task tool results. Tests cover paraphrases, unrelated-note rejection, lexical fallback, explicit denials, blocked actions, current-task context and old snapshot decoding. Initial CI exposed a weak token match and review found a context-window edge case; both were corrected. An intermediate update run failed to compile after the test source was truncated during transfer; the complete source was restored before final validation. PR run 46082211356 and integrated run 46083177104 passed all required jobs. Physical-device retesting remains needed to establish whether Tim's reported diagnostics are resolved. This workspace lacks Swift; local checks were `git diff --check` and the build-script fixtures.

JSON remains authoritative until the migration safety gates pass. Do not modify upstream `main`, add network/model downloads, or commit signing material.

## Current increment — Swift-first upstream agent contract adapter

The owner selected Swift-first orchestration while retaining Apple Foundation Models. ADR-0009 now accepts this boundary: `Agent` implements the pinned upstream `OjAgent` call shape, context is exchanged using upstream `AgentContext`/`AgentResult`/`ToolResult` field contracts, and `SessionCoordinator` routes new submissions through that interface. Permission context is derived locally and rejected if altered; request denials filter the advertised action list; memory writes still pause for explicit approval. Contract-parity, context-tampering, denial and approval tests are authored. The app continues to use its existing Swift loop and does not link the upstream concrete Rust `openjarvis-agents` crate, `rig-core` or `reqwest`; no claim of Rust-agent integration is made.

This feature branch is based on `ios/main`, independent of PR #25's SQLite CRUD prerequisite. `git diff --check` and shell/build-script fixtures pass. Swift/Xcode/Rust builds and regression suites have not run in this Linux environment; require full CI before integration. PR #26 contains the separate physical-diagnostics increment. SQLite production migration remains gated on PR #25 validation and signed-device file-protection evidence.

## Dependency and validation queue

PR #25 is the transactional SQLite backend prerequisite; its last single Actions lookup returned no run for its current head. Do not repeatedly poll, and do not merge until all required checks are successful. ADR-0008 requires validation of this foundation before production migration-state work. PR #26 adds synthetic physical-inference diagnostics; its full CI and an actual signed-device report remain pending. Neither simulator compilation nor unsigned device compilation is physical execution evidence.
