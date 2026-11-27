# Current handoff — v0.4.1 complete; memory retrieval PR in validation

Date: 2026-11-27 ET. `ios/main` is `c16298a4015ac9384f6329290c7997c928f60c61` after PR #21. PR #20 validation run 46070616432 and integrated run 46072060277 passed; PR #21 run 46073658513 and integrated run 46074641626 also passed all seven jobs. The runtime baseline includes 55 portable Swift tests, 10 Rust bridge tests, 11 hosted native simulator tests, security audits, ARM64 `iphoneos` and simulator builds, IPA packaging and artifact upload.

## Owner-reported Mac validation

On 2026-11-27, Tim reported configuring an Apple silicon Mac with Xcode 27.2, XcodeGen and Rust, passing all 55 Swift core tests, compiling simulator and physical-device targets, and packaging an unsigned IPA. The tested commit and local logs were not supplied; keep this evidence owner-reported and unattributed to a specific SHA.

Tim later reported actual OpenJarvis execution on a physical iPhone using synthetic prompts: four basic responses passed, the request “Explain how a seed grows. Do not use tools or memory.” failed, and six targeted semantic-retrieval prompts failed. Device model, OS version, tested commit and logs/timings were not provided. This establishes partial physical-device execution, not complete G5 acceptance, overall feature correctness or performance. See `docs/validation/physical-memory-diagnostics.md`.

## Release artifact pipeline — merged and validated

PR #20 adds the reusable repository security audit as a required native-build dependency, valid `ios-vX.Y.Z` tag validation against `ios/main`, tag-derived app version/build number, unsigned IPA packaging and checksummed artifacts. The validated PR and integrated CI runs uploaded development IPAs. Integrated artifact 15233712034 is available from [workflow run 46072060277](https://github.com/tfredx/OpenJarvis/actions/runs/46072060277); its package contains the device and simulator app bundles, IPA, manifest and checksums. I downloaded the PR artifact from run 46070616432 and verified its ZIP checksums and `Payload/OpenJarvisMobile.app/Info.plist`; the IPA manifest explicitly reports `physical_device_tested: false`.

No `ios-vX.Y.Z` tag has been created, so tag-specific version injection and 90-day release-artifact publication are configured but have not yet run. No signed, App Store or production release was created. Release artifacts require developer signing for installation.

## Current code increment — semantic recall and request policy

PR #22 (`fix/ios-memory-retrieval`) adds local Apple sentence-embedding ranking with lexical fallback for approved memories, and enforces user requests to avoid tools/memory before context assembly and action dispatch. Denied tasks exclude stored notes and prior-task history while retaining results from tools permitted in the current task. Regression tests cover paraphrase ranking, unrelated-note rejection, lexical fallback, explicit denials, blocked model actions, current-task result retention and decoding older snapshots. Initial CI run 46079296252 exposed a weak-match fixture false positive because the article “a” counted as a lexical match; token ranking now ignores tokens shorter than three characters. Corrected code run 46079501679 passed all seven jobs: 62 portable Swift tests, 10 Rust bridge tests/cross-build, 11 hosted native integration tests, security audits, unsigned arm64 iPhoneOS and simulator builds, and IPA packaging/upload (artifact 15236438029). Automated review then caught a context-history edge case; the current fix preserves allowed current-task tool results but excludes earlier conversation. Latest full run 46081141460 passed all jobs at its documentation-only commit; rerun full CI for the current code head before merge. The workspace has no Swift toolchain; local validation is `git diff --check` plus shell/build-script fixtures. Physical-device retesting is required to establish whether the reported diagnostics are resolved.

JSON remains authoritative until the migration safety gates pass. Do not modify upstream `main`, add network/model downloads, or commit signing material.

## Next — upstream agent adapter

The v0.5 integration needs an architectural choice. The pinned upstream `openjarvis-agents` crate requires a `rig-core::CompletionModel`; its `NativeReActAgent` executes through `ToolExecutor` without the app's explicit approval gate. At this pin, `OrchestratorAgent` is still a one-turn chat wrapper and does not dispatch tools. `rig-core` brings a `reqwest` dependency graph. The app instead uses asynchronous Apple Foundation Models in Swift, and ADR-0002 deliberately keeps inference and tool authorization outside the Rust bridge.

Before implementing v0.5, choose whether to keep Apple inference and approvals in Swift with a narrow adapter around upstream core contracts, or build an asynchronous Rust-to-Swift model bridge and integrate the Rust agent crate behind a restricted approval-aware tool executor. Do not report original upstream orchestration as integrated until the chosen runtime actually uses its agent API and has regression coverage. Do not add generic network, shell, or file tools. Other roadmap work continues independently of this decision.
