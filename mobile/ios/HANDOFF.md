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

## Next — upstream agent adapter

The v0.5 integration needs an architectural choice. The pinned upstream `openjarvis-agents` crate requires a `rig-core::CompletionModel`; its `NativeReActAgent` executes through `ToolExecutor` without the app's explicit approval gate. At this pin, `OrchestratorAgent` is still a one-turn chat wrapper and does not dispatch tools. `rig-core` brings a `reqwest` dependency graph. The app instead uses asynchronous Apple Foundation Models in Swift, and ADR-0002 deliberately keeps inference and tool authorization outside the Rust bridge.

SQLite shadow migration is validated, but JSON remains authoritative; the next implementation increment should wire SQLite reads/writes behind the existing migration gates and add restart, rollback and preservation coverage. For v0.5, an architectural decision is still required: keep Apple inference and approvals in Swift with a narrow adapter around upstream core contracts, or build an asynchronous Rust-to-Swift model bridge and integrate the Rust agent crate behind a restricted approval-aware tool executor. Do not report original upstream orchestration as integrated until runtime uses its API with regression coverage. Do not add generic network, shell or file tools. Other roadmap work continues independently.
