# Current handoff — SQLite CRUD integrated; validation status unknown; capability seam in progress

Date: 2026-11-28 ET. `ios/main` advanced to `ede3b2242979fe0545dc93e74f718a2535a9d338` when PR #25 merged. PR #22 run 46082211356/integrated 46083177104 and PR #23 run 46084387629/integrated 46085721355 passed all seven jobs, including portable Swift regressions, Rust bridge tests/cross-build, hosted native integration, security audits, unsigned iPhoneOS and simulator builds, and artifact packaging. Artifacts 15237619676 and 15238954029 were uploaded. PR #25's integrated push-run could not be independently verified with the connected GitHub status tools: workflow lookup exposed no PR runs for its merge commit and combined status returned no contexts. Treat that validation as unknown, not passed.

## Owner-reported Mac validation

On 2026-11-27, Tim reported configuring an Apple silicon Mac with Xcode 27.2, XcodeGen and Rust, passing all 55 Swift core tests, compiling simulator and physical-device targets, and packaging an unsigned IPA. The tested commit and local logs were not supplied; keep this evidence owner-reported and unattributed to a specific SHA.

Tim later reported actual OpenJarvis execution on a physical iPhone using synthetic prompts: four basic responses passed, the request “Explain how a seed grows. Do not use tools or memory.” failed, and six targeted semantic-retrieval prompts failed. Device model, OS version, tested commit and logs/timings were not provided. This establishes partial physical-device execution, not complete G5 acceptance, overall feature correctness or performance. See `docs/validation/physical-memory-diagnostics.md`.

## Release artifact pipeline — merged and validated

PR #20 adds the reusable repository security audit as a required native-build dependency, valid `ios-vX.Y.Z` tag validation against `ios/main`, tag-derived app version/build number, unsigned IPA packaging and checksummed artifacts. The validated PR and integrated CI runs uploaded development IPAs. Integrated artifact 15233712034 is available from [workflow run 46072060277](https://github.com/tfredx/OpenJarvis/actions/runs/46072060277); its package contains the device and simulator app bundles, IPA, manifest and checksums. I downloaded the PR artifact from run 46070616432 and verified its ZIP checksums and `Payload/OpenJarvisMobile.app/Info.plist`; the IPA manifest explicitly reports `physical_device_tested: false`.

No `ios-vX.Y.Z` tag has been created, so tag-specific version injection and 90-day release-artifact publication are configured but have not yet run. No signed, App Store or production release was created. Release artifacts require developer signing for installation.

## Current code increment — semantic recall and request policy

PR #22 adds on-device Apple sentence-embedding ranking with lexical fallback for approved memories, and enforces request-level denials before context assembly and action dispatch. Denied tasks exclude stored notes and prior-task history while retaining allowed current-task tool results. Tests cover paraphrases, unrelated-note rejection, lexical fallback, explicit denials, blocked actions, current-task context and old snapshot decoding. Initial CI exposed a weak token match and review found a context-window edge case; both were corrected. An intermediate update run failed to compile after the test source was truncated during transfer; the complete source was restored before final validation. PR run 46082211356 and integrated run 46083177104 passed all required jobs. Physical-device retesting remains needed to establish whether Tim's reported diagnostics are resolved. This workspace lacks Swift; local checks were `git diff --check` and the build-script fixtures.

JSON remains authoritative until the migration safety gates pass. Do not modify upstream `main`, add network/model downloads, or commit signing material.

## Current increment — transactional SQLite session operations

PR #25 merged transactional create, rename, select, snapshot-save, delete and explicit erase operations and their tests into `ios/main`. PR #24's earlier native run 46086033077 ended cancelled at diagnostics-artifact retention and is not a successful required check. PR #25's complete CI conclusion and the integrated push-run remain unverified here. SQLite is not wired into `SessionRepository`, `SessionCoordinator` or app startup; JSON remains the production store. Do not start migration/cutover until integrated CI and physical file-protection evidence are verified.

## Current code increments — diagnostics and Swift-first upstream agent adapter

PR #26 adds an opt-in eight-scenario synthetic inference diagnostic with a report that excludes prompt/output/memory text. Its CI and physical run are not asserted here. PR #27 adds a Swift-first adapter using pinned upstream `OjAgent`, `AgentContext`, `AgentResult` and `ToolResult` contracts, while preserving Apple Foundation Models, request denials and explicit memory approvals. The adapter does not link the concrete Rust agent, `rig-core` or `reqwest`. Its Swift tests are authored but unrun in this Linux environment. Both PR branches were updated to the merged base using merge commits without force-pushing.

## Current increment — permission-neutral native capability interface

Branch `feat/ios-native-capability-interfaces` defines fixed native capability IDs, typed adapter/request/result interfaces, a registry with duplicate rejection, default-deny authorization, fail-closed approval and per-invocation human approval. Regression tests cover unregistered/unknown IDs, default-deny policy, declined/approved actions, repeated approvals, malformed/oversized inputs, duplicate adapters and oversized output. No native provider is registered; no Info.plist usage descriptions, entitlements or OS permissions are added. This is an API seam only and does not claim Calendar, Contacts, Photos, Reminders or Location functionality. Swift tests are authored but not run here.

`git diff --check` and the existing shell/build-script fixtures pass. Swift/Xcode/Cargo are unavailable in this workspace. Full CI remains required for PRs #26/#27 and this branch. Simulator/device compilation is not physical-device runtime evidence; actual signed-device diagnostics remain pending.
